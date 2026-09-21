local FakeFilesystem = require("fs.FakeFilesystem")
local SkinRegistry = require("rizu.skin.SkinRegistry")

local test = {}

local valid_skin = [[
return {
	metadata = {name = "Example", author = "Rizu", version = "1", gamemode = "mania", input_modes = {"4key"}},
	load = function(context) return context end,
}
]]

---@param t testing.T
function test.discovers_native_lua_skin_metadata(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/noteskins/example")
	fs:write("userdata/noteskins/example/example.skin.lua", valid_skin)

	local registry = SkinRegistry(fs)
	registry:load()

	local skins = registry:getSkins()
	t:eq(#skins, 1)
	t:eq(skins[1].path, "userdata/noteskins/example/example.skin.lua")
	t:eq(skins[1].directory_path, "userdata/noteskins/example")
	t:eq(skins[1].file_name, "example.skin.lua")
	t:eq(skins[1].format, "lua")
	t:eq(skins[1].metadata.name, "Example")
	t:eq(registry:getSkin(skins[1].path), skins[1])
	t:eq(registry:getSkinForInputMode("mania", "4key"), skins[1])
	t:eq(registry:getSkinForInputMode("mania", "7key"), nil)
	t:eq(skins[1].load("context"), "context")
end

---@param t testing.T
function test.discovers_external_skin_packages_without_executing_their_lua(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/noteskins/stepmania")
	fs:write("userdata/noteskins/stepmania/NoteSkin.lua", "error('must not execute')")
	fs:createDirectory("userdata/noteskins/osu")
	fs:write("userdata/noteskins/osu/skin.ini", "[General]\nName: Example")

	local registry = SkinRegistry(fs)
	registry:load()

	local skins = registry:getSkins()
	t:eq(#skins, 2)
	t:eq(skins[1].format, "osu")
	t:eq(skins[1].metadata.name, "osu")
	t:eq(skins[2].format, "stepmania")
	t:eq(skins[2].metadata.name, "stepmania")
end

---@param t testing.T
function test.isolates_invalid_lua_skins(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata/noteskins")
	fs:write("userdata/noteskins/bad.skin.lua", "return {metadata = {name = 'Bad'}}")
	fs:write("userdata/noteskins/bytecode.skin.lua", string.char(27) .. "Lua")
	fs:write("userdata/noteskins/good.skin.lua", valid_skin)

	local registry = SkinRegistry(fs)
	registry:load()

	t:eq(#registry:getSkins(), 1)
	t:assert(registry.errors["userdata/noteskins/bad.skin.lua"])
	t:assert(registry.errors["userdata/noteskins/bytecode.skin.lua"])
end

return test
