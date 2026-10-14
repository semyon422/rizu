local FakeFilesystem = require("fs.FakeFilesystem")
local SkinRegistry = require("rizu.skin.SkinRegistry")
local Settings = require("rizu.config.Settings")

local test = {}

---@param paths {[string]: string}?
local function new_settings(paths)
	local settings = Settings.createConfig(FakeFilesystem())
	settings:setStringMap(Settings.keys.gameplay.skins, paths or {})
	return settings
end

local osu_ini = "[General]\nName: %s\nAuthor: Mapper\nVersion: 2.7\n[Mania]\nKeys: 4\n"

---@param fs fs.IFilesystem
---@param name string
---@param ini string?
local function add_osu_skin(fs, name, ini)
	fs:createDirectory("userdata/dlc/skins_osu/" .. name)
	fs:write("userdata/dlc/skins_osu/" .. name .. "/skin.ini", ini or osu_ini:format(name))
end

---@param fs fs.IFilesystem
---@param name string
---@param source string?
local function add_lua_skin(fs, name, source)
	fs:createDirectory("userdata/dlc/skins_rizu/" .. name)
	fs:write("userdata/dlc/skins_rizu/" .. name .. "/skin.lua", source or [[
return {
	name = "Example", gamemode = "mania", input_modes = {"4key"},
	load = function(game, directory, input_mode, config, screen) return {game, directory, input_mode, config, screen} end,
}
]])
end

---@param t testing.T
function test.lists_builtin_then_lua_then_osu_skins_with_one_shape(t)
	local fs = FakeFilesystem()
	add_osu_skin(fs, "Custom Skin")
	add_lua_skin(fs, "example")
	fs:createDirectory("userdata/dlc/skins_rizu/base") -- config folder, not a skin
	fs:createDirectory("userdata/dlc/skins_osu/no-ini")
	fs:write("userdata/dlc/skins_osu/no-ini/readme.txt", "not a skin")

	local registry = SkinRegistry(fs, new_settings())
	registry:load()

	local skins = registry:getSkins()
	local paths = {}
	for _, skin in ipairs(skins) do table.insert(paths, skin.path) end
	t:tdeq(paths, {
		"builtin/mania", "builtin/sdvx",
		"userdata/dlc/skins_rizu/example", "userdata/dlc/skins_osu/Custom Skin",
	})
	t:eq(skins[3].format, "lua")
	t:eq(skins[3].name, "Example")
	t:eq(skins[4].format, "osu")
	t:eq(skins[4].name, "Custom Skin")
	t:eq(skins[4].author, "Mapper")
	t:eq(skins[4].version, "2.7")
	t:eq(registry:getSkin("userdata/dlc/skins_osu/Custom Skin/"), skins[4])
end

---@param t testing.T
function test.osu_skin_matches_skin_ini_case_insensitively_and_indexes_files_on_demand(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/dlc/skins_osu/Custom/Textures")
	fs:write("userdata/dlc/skins_osu/Custom/SKiN.INi", "[General]\nName:\n")
	fs:write("userdata/dlc/skins_osu/Custom/cursor@2x.png", "cursor")
	fs:write("userdata/dlc/skins_osu/Custom/Textures/hitcircle.png", "texture")
	fs:createDirectory("userdata/dlc/skins_osu/nested/sub")
	fs:write("userdata/dlc/skins_osu/nested/sub/skin.ini", "[General]\nName: Nested\n")

	local registry = SkinRegistry(fs, new_settings())
	registry:load()
	local skin = registry:getSkin("userdata/dlc/skins_osu/Custom")
	assert(skin)

	t:eq(skin.name, "Custom") -- an empty Name falls back to the directory
	t:eq(rawget(skin, "files"), nil)
	t:tdeq(skin.files, {"SKiN.INi", "Textures/hitcircle.png", "cursor@2x.png"})
	t:eq(rawget(skin, "files"), skin.files)
	t:eq(registry:getSkin("userdata/dlc/skins_osu/nested"), nil) -- skin.ini only counts in the root
end

---@param t testing.T
function test.invalid_lua_skins_are_skipped(t)
	local fs = FakeFilesystem()
	add_lua_skin(fs, "bad", "return {name = 'Bad'}")
	add_lua_skin(fs, "bytecode", string.char(27) .. "Lua")
	add_lua_skin(fs, "throws", "error('boom')")
	add_lua_skin(fs, "good")

	local registry = SkinRegistry(fs, new_settings())
	registry:load()

	t:eq(#registry:getSkins(), 3)
	t:eq(registry:getSkins()[3].name, "Example")
end

---@param t testing.T
function test.skins_for_a_gamemode_respect_input_modes(t)
	local fs = FakeFilesystem()
	add_lua_skin(fs, "example")
	add_osu_skin(fs, "osu-example")
	local registry = SkinRegistry(fs, new_settings())
	registry:load()

	local function names(gamemode, input_mode)
		local list = {}
		for _, skin in ipairs(registry:getSkinsFor(gamemode, input_mode)) do table.insert(list, skin.name) end
		return list
	end
	t:tdeq(names("mania", "4key"), {"Rizu Default", "Example", "osu-example"})
	t:tdeq(names("mania", "7key"), {"Rizu Default", "osu-example"})
	t:tdeq(names("taiko", "1taiko"), {"osu-example"})
	t:tdeq(names("sdvx", "4bt"), {"Rizu SDVX"})
end

---@param t testing.T
function test.resolve_follows_settings_and_falls_back(t)
	local fs = FakeFilesystem()
	add_lua_skin(fs, "example")
	add_osu_skin(fs, "first")
	add_osu_skin(fs, "second")
	local settings = new_settings()
	local registry = SkinRegistry(fs, settings)
	registry:load()
	local second = assert(registry:getSkin("userdata/dlc/skins_osu/second"))
	local lua_skin = assert(registry:getSkin("userdata/dlc/skins_rizu/example"))

	t:eq(registry:resolve("mania", "4key").path, "builtin/mania")
	t:eq(registry:resolve("osu", "1osu").path, "userdata/dlc/skins_osu/first")

	registry:select("mania", "4key", second)
	registry:select("taiko", "1taiko", second)
	t:eq(settings:getStringMap(Settings.keys.gameplay.skins)["mania/4key"], second.path)
	t:eq(settings:getStringMap(Settings.keys.gameplay.skins)["osu/1taiko"], second.path)
	t:eq(registry:resolve("mania", "4key"), second)
	t:eq(registry:resolve("taiko", "1taiko"), second)
	-- Another key count and another osu! gamemode are not affected.
	t:eq(registry:resolve("mania", "7key").path, "builtin/mania")
	t:eq(registry:resolve("osu", "1osu").path, "userdata/dlc/skins_osu/first")

	-- A lua skin cannot draw a key count it does not list: the choice is stale.
	registry:select("mania", "7key", lua_skin)
	t:eq(registry:resolve("mania", "7key").path, "builtin/mania")
	registry:select("mania", "4key", lua_skin)
	t:eq(registry:resolve("mania", "4key"), lua_skin)

	-- One choice for the whole osu! family, unless a gamemode has its own.
	settings:setStringMap(Settings.keys.gameplay.skins, {["osu/1osu"] = second.path})
	t:eq(registry:resolve("catch", "1fruits"), second)
	-- A removed skin falls back instead of failing.
	settings:setStringMap(Settings.keys.gameplay.skins, {["osu/1osu"] = "userdata/dlc/skins_osu/gone"})
	t:eq(registry:resolve("osu", "1osu").path, "userdata/dlc/skins_osu/first")
end

---@param t testing.T
function test.createRenderer_loads_a_lua_skin_with_its_own_config(t)
	local fs = FakeFilesystem()
	add_lua_skin(fs, "example")
	local registry = SkinRegistry(fs, new_settings())
	registry:load()
	local skin = assert(registry:getSkin("userdata/dlc/skins_rizu/example"))

	local renderer, config, config_path = registry:createRenderer(skin, "game", "mania", "4key", "gameplay")
	t:eq(config_path, "userdata/dlc/skins_rizu/example/skin-config.json")
	t:eq(renderer[1], "game")
	t:eq(renderer[2], skin.path)
	t:eq(renderer[3], "4key")
	t:eq(renderer[4], config)
	t:eq(renderer[5], "gameplay")
	config:set("mania", "4key", "receptor.y", 320)
	config:save(fs, config_path)

	local _, reloaded = registry:createRenderer(skin, "game", "mania", "4key", "preview")
	t:assert(reloaded ~= config)
	t:eq(reloaded:get("mania", "4key", "receptor.y"), 320)
end

---@param t testing.T
function test.builtin_mania_config_stays_in_the_base_skin_folder(t)
	local registry = SkinRegistry(FakeFilesystem(), new_settings())
	registry:load()
	t:eq(registry:getConfigPath(registry:getSkin("builtin/mania")),
		"userdata/dlc/skins_rizu/base/rizu_mania.skin-config.json")
end

---@param t testing.T
function test.load_notifies_listeners(t)
	local registry = SkinRegistry(FakeFilesystem(), new_settings())
	local calls = 0
	registry:onChanged(function() calls = calls + 1 end)
	registry:load()
	registry:load()
	t:eq(calls, 2)
end

return test
