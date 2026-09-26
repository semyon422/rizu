local FakeFilesystem = require("fs.FakeFilesystem")
local SkinRegistry = require("rizu.skin.SkinRegistry")

local test = {}

local valid_skin = [[
return {
	metadata = {name = "Example", author = "Rizu", version = "1", gamemode = "mania", input_modes = {"4key"}},
	load = function(game, input_mode, screen) return game, input_mode, screen end,
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
	local game, input_mode, screen = skins[1].load("game", "4key", "preview")
	t:eq(game, "game")
	t:eq(input_mode, "4key")
	t:eq(screen, "preview")
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
		t:eq(registry:getSkin(skin.path), nil)
	end
	t:eq(discovered["userdata/dlc/skins_stepmania/dance/example"].name, "example")
	t:tdeq(discovered["userdata/dlc/skins_stepmania/dance/example"].input_modes, {"4key"})
	t:tdeq(discovered["userdata/dlc/skins_stepmania/kb7/example"].input_modes, {"7key"})
	t:tdeq(discovered["userdata/dlc/skins_stepmania/beat/example"].input_modes, {"5key", "7key"})
	t:eq(discovered["userdata/dlc/skins_stepmania/common/example"], nil)
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
