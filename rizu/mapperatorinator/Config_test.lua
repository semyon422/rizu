local FakeFilesystem = require("fs.FakeFilesystem")
local MapperatorinatorConfig = require("rizu.mapperatorinator.Config")

local test = {}

---@param t testing.T
function test.defaults_and_persistence(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	local config = MapperatorinatorConfig.create(fs, "/home/test")
	t:eq(config:getString(MapperatorinatorConfig.keys.repository_path), "/home/test/code/Mapperatorinator")
	t:eq(config:getString(MapperatorinatorConfig.keys.python_path), "/home/test/code/Mapperatorinator/.venv/bin/python")
	t:eq(config:getChoice(MapperatorinatorConfig.keys.gamemode), "osu!mania")
	t:eq(config:getNumber(MapperatorinatorConfig.keys.difficulty), 5)
	t:eq(config:getNumber(MapperatorinatorConfig.keys.keycount), 4)
	t:eq(config:getNumber(MapperatorinatorConfig.keys.year), 2024)

	config:setNumber(MapperatorinatorConfig.keys.keycount, 7)
	t:eq(config:save(), true)
	local loaded = MapperatorinatorConfig.create(fs, "/home/test")
	t:eq(loaded:load(), true)
	t:eq(loaded:getNumber(MapperatorinatorConfig.keys.keycount), 7)
end

return test
