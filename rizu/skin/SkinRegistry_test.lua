local FakeFilesystem = require("fs.FakeFilesystem")
local SkinRegistry = require("rizu.skin.SkinRegistry")

local test = {}

local valid_skin = [[
return {
	metadata = {name = "Example", author = "Rizu", version = "1", gamemode = "mania", input_modes = {"4key"}},
	load = function(context) return context.game end,
}
]]

---@param t testing.T
function test.discovers_native_lua_skin_metadata(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_rizu/example")
	fs:write("userdata/dlc/skins_rizu/example/example.skin.lua", valid_skin)

	local registry = SkinRegistry(fs)
	registry:load()

	local skins = registry:getSkins()
	t:eq(#skins, 1)
	t:eq(skins[1].path, "userdata/dlc/skins_rizu/example/example.skin.lua")
	t:eq(skins[1].directory_path, "userdata/dlc/skins_rizu/example")
	t:eq(skins[1].file_name, "example.skin.lua")
	t:eq(skins[1].format, "lua")
	t:eq(skins[1].metadata.name, "Example")
	t:eq(registry:getSkin(skins[1].path), skins[1])
	t:eq(registry:getSkinForInputMode("mania", "4key"), skins[1])
	t:eq(registry:getSkinForInputMode("mania", "7key"), nil)
	local game = registry:loadSkin(skins[1], "game", "4key", "preview")
	t:eq(game, "game")
end

---@param t testing.T
function test.loadSkin_provides_paths_and_custom_loader(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_rizu/renamed_skin")
	fs:createDirectory("rizu/skin/base")
	fs:write("userdata/dlc/skins_rizu/renamed_skin/custom.skin.lua", [[
return {
	metadata = {name = "Custom", gamemode = "mania", input_modes = {"4key"}},
	load = function(context) return context end,
}
]])
	fs:write("rizu/skin/base/base.skin.lua", [[
return {
	metadata = {name = "Base", gamemode = "mania", input_modes = {"4key"}},
	load = function(context) return context end,
}
]])
	local registry = SkinRegistry(fs)
	registry:load()
	local renderer = registry:loadSkin(registry:getSkin("userdata/dlc/skins_rizu/renamed_skin/custom.skin.lua"),
		{}, "4key", "gameplay")
	local base_renderer = registry:loadSkin(registry:getSkin("rizu/skin/base/base.skin.lua"),
		{}, "4key", "gameplay")
	t:eq(renderer.directory_path, "userdata/dlc/skins_rizu/renamed_skin")
	t:eq(base_renderer.directory_path, "rizu/skin/base")
	t:eq(base_renderer.module_loader, nil)
	t:assert(renderer.module_loader)
	t:assert(not pcall(base_renderer.loadModule, base_renderer, "Font"))
end

---@param t testing.T
function test.custom_skin_receives_module_loader(t)
	local fs = FakeFilesystem()
	local directory = "userdata/dlc/skins_rizu/renamed"
	fs:createDirectory(directory)
	fs:write(directory .. "/Font.lua", "return {}")
	fs:write(directory .. "/custom.skin.lua", [[
return {
	metadata = {name = "Custom", gamemode = "mania", input_modes = {"4key"}},
	load = function(context)
		return {font = context:loadModule("Font"), context = context}
	end,
}
]])
	local registry = SkinRegistry(fs)
	registry:load()
	local renderer = registry:loadSkin(registry:getSkins()[1], {}, "4key", "gameplay")
	t:eq(renderer.font, renderer.context:loadModule("Font"))
end

---@param t testing.T
function test.loads_skin_with_an_instance_scoped_config(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_rizu/example")
	fs:write("userdata/dlc/skins_rizu/example/example.skin.lua", valid_skin)
	local registry = SkinRegistry(fs)
	registry:load()
	local skin = registry:getSkins()[1]

	local first_renderer, first_config, first_path = registry:loadSkin(skin, {}, "4key", "gameplay")
	local second_renderer, second_config = registry:loadSkin(skin, {}, "4key", "preview")
	t:tdeq(first_renderer, {})
	t:tdeq(second_renderer, {})
	t:assert(first_config ~= second_config)
	t:eq(first_path, "userdata/dlc/skins_rizu/example/example.skin-config.json")
	first_config:set("mania", "4key", "receptor.y", 320)
	t:eq(second_config:getOverride("mania", "4key", "receptor.y"), nil)
	first_config:save(fs, first_path)

	local reloaded_renderer, reloaded_config = registry:loadSkin(skin, {}, "4key", "gameplay")
	t:tdeq(reloaded_renderer, {})
	t:eq(reloaded_config:getOverride("mania", "4key", "receptor.y"), 320)
end

---@param t testing.T
function test.base_skin_config_uses_userdata_base_directory(t)
	local registry = SkinRegistry(FakeFilesystem())
	local path = registry:getSkinConfigPath({path = "rizu/skin/base/rizu_mania.skin.lua"})
	t:eq(path, "userdata/dlc/skins_rizu/base/rizu_mania.skin-config.json")
end

---@param t testing.T
function test.discovers_skins_stepmania_in_etterna_game_type_directories(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_stepmania/dance/example")
	fs:write("userdata/dlc/skins_stepmania/dance/example/NoteSkin.lua", "error('must not execute during discovery')")
	fs:createDirectory("userdata/dlc/skins_stepmania/kb7/example")
	fs:write("userdata/dlc/skins_stepmania/kb7/example/Noteskin.lua", "error('must not execute during discovery')")
	fs:createDirectory("userdata/dlc/skins_stepmania/beat/example")
	fs:write("userdata/dlc/skins_stepmania/beat/example/metrics.ini", "")
	fs:createDirectory("userdata/dlc/skins_stepmania/common/example")
	fs:write("userdata/dlc/skins_stepmania/common/example/metrics.ini", "")

	local registry = SkinRegistry(fs)
	registry:load()

	t:eq(#registry:getSkins(), 0)
	t:eq(registry:getSkinForInputMode("mania", "4key"), nil)

	local discoveries = registry:getStepmaniaSkins()
	t:eq(#discoveries, 3)
	local discovered = {}
	for _, skin in ipairs(discoveries) do
		discovered[skin.path] = skin
		t:eq(skin.format, "stepmania")
		t:eq(registry:getSkin(skin.path), nil)
	end
	t:eq(discovered["userdata/dlc/skins_stepmania/dance/example"].name, "example")
	t:eq(discovered["userdata/dlc/skins_stepmania/dance/example"].format, "stepmania")
	t:eq(discovered["userdata/dlc/skins_stepmania/dance/example"].directory_path,
		"userdata/dlc/skins_stepmania/dance/example")
	t:tdeq(discovered["userdata/dlc/skins_stepmania/dance/example"].input_modes, {"4key"})
	t:tdeq(discovered["userdata/dlc/skins_stepmania/kb7/example"].input_modes, {"7key"})
	t:tdeq(discovered["userdata/dlc/skins_stepmania/beat/example"].input_modes, {"5key", "7key"})
	t:eq(discovered["userdata/dlc/skins_stepmania/common/example"], nil)
end

---@param t testing.T
function test.discovers_osu_skins_from_root_skin_ini_case_insensitively(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_osu/Custom Skin/Textures")
	fs:write("userdata/dlc/skins_osu/Custom Skin/SKiN.INi", [[
[General]
Name: Custom Name
Author: Mapper
Version: 2.7
[Mania]
Keys: 7
[Mania]
Keys: 4
[Mania]
Keys: 7
]])
	fs:write("userdata/dlc/skins_osu/Custom Skin/cursor@2x.png", "cursor")
	fs:write("userdata/dlc/skins_osu/Custom Skin/Textures/hitcircle.png", "texture")
	fs:createDirectory("userdata/dlc/skins_osu/nested")
	fs:createDirectory("userdata/dlc/skins_osu/nested/subfolder")
	fs:write("userdata/dlc/skins_osu/nested/subfolder/skin.ini", "[General]\nName: Nested\n")
	fs:createDirectory("userdata/dlc/skins_osu/no-config")
	fs:write("userdata/dlc/skins_osu/no-config/readme.txt", "not a skin")

	local registry = SkinRegistry(fs)
	registry:load()

	local skins = registry:getOsuSkins()
	t:eq(#skins, 1)
	t:eq(skins[1].name, "Custom Name")
	t:eq(skins[1].path, "userdata/dlc/skins_osu/Custom Skin")
	t:eq(skins[1].directory_path, skins[1].path)
	t:eq(skins[1].file_name, "SKiN.INi")
	t:tdeq(skins[1].files, {"SKiN.INi", "Textures/hitcircle.png", "cursor@2x.png"})
	t:eq(skins[1].format, "osu")
	t:tdeq(skins[1].input_modes, {"4key", "7key"})
	t:eq(skins[1].metadata.author, "Mapper")
	t:eq(skins[1].metadata.version, "2.7")
	t:eq(skins[1].metadata.gamemode, "mania")
	t:tdeq(skins[1].metadata.input_modes, {"4key", "7key"})
	t:eq(skins[1].skin_ini.Mania[1].Keys, "7")
	t:assert(type(skins[1].load) == "function")
	t:eq(registry:getOsuSkin(skins[1].path), skins[1])
	t:eq(#registry:getSkins(), 0) -- Native Rizu skin collection remains separate.
end

---@param t testing.T
function test.resolves_selected_skin_across_supported_formats(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_rizu/example")
	fs:write("userdata/dlc/skins_rizu/example/example.skin.lua", valid_skin)
	fs:createDirectory("userdata/dlc/skins_osu/osu-example")
	fs:write("userdata/dlc/skins_osu/osu-example/skin.ini", [[
[General]
Name: Osu Example
[Mania]
Keys: 4
]])

	local registry = SkinRegistry(fs)
	registry:load()
	local native_skin = registry:getSkins()[1]
	local osu_skin = registry:getOsuSkins()[1]
	t:eq(registry:getSkin(osu_skin.path), osu_skin)
	t:eq(registry:getSkinForInputMode("mania", "4key", osu_skin.path .. "/"), osu_skin)
	t:eq(registry:getSkinForInputMode("mania", "4key", native_skin.path), native_skin)

	local loaded
	osu_skin.load = function(context)
		loaded = {context.game, context.input_mode, context.screen}
		return "osu-renderer"
	end
	local renderer, config, config_path = registry:loadSkin(osu_skin, "game", "4key", "preview")
	t:eq(renderer, "osu-renderer")
	t:assert(config)
	t:eq(config_path, "userdata/dlc/skins_osu/osu-example/skin-config.json")
	t:tdeq(loaded, {"game", "4key", "preview"})
end

---@param t testing.T
function test.isolates_invalid_lua_skins(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_rizu")
	fs:write("userdata/dlc/skins_rizu/bad.skin.lua", "return {metadata = {name = 'Bad'}}")
	fs:write("userdata/dlc/skins_rizu/bytecode.skin.lua", string.char(27) .. "Lua")
	fs:write("userdata/dlc/skins_rizu/good.skin.lua", valid_skin)

	local registry = SkinRegistry(fs)
	registry:load()

	t:eq(#registry:getSkins(), 1)
	t:assert(registry.errors["userdata/dlc/skins_rizu/bad.skin.lua"])
	t:assert(registry.errors["userdata/dlc/skins_rizu/bytecode.skin.lua"])
end

return test
