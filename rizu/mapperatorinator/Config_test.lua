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
	t:eq(config:getChoice(MapperatorinatorConfig.keys.model), "v32")
	t:eq(config:getChoice(MapperatorinatorConfig.keys.precision), "bf16")
	t:eq(config:getChoice(MapperatorinatorConfig.keys.attn_implementation), "auto")
	t:eq(config:getBoolean(MapperatorinatorConfig.keys.hitsounded), true)
	t:eq(config:getString(MapperatorinatorConfig.keys.descriptors), "")

	config:setNumber(MapperatorinatorConfig.keys.keycount, 7)
	t:eq(config:save(), true)
	local loaded = MapperatorinatorConfig.create(fs, "/home/test")
	t:eq(loaded:load(), true)
	t:eq(loaded:getNumber(MapperatorinatorConfig.keys.keycount), 7)

	MapperatorinatorConfig.reset(loaded)
	t:eq(loaded:getNumber(MapperatorinatorConfig.keys.keycount), 4)
	t:eq(loaded:getChoice(MapperatorinatorConfig.keys.model), "v32")
end

---@param t testing.T
function test.migrates_expanded_prototype_keys(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	fs:write("userdata/mapperatorinator.json", [[{
		"mapperatorinator.paths.repository": "/repo",
		"mapperatorinator.paths.python": "/python",
		"mapperatorinator.basic.gamemode": "osu!standard",
		"mapperatorinator.difficulty.keycount": 7
	}]])
	local config = MapperatorinatorConfig.create(fs, "/home/test")
	t:eq(config:getString(MapperatorinatorConfig.keys.repository_path), "/repo")
	t:eq(config:getString(MapperatorinatorConfig.keys.python_path), "/python")
	t:eq(config:getChoice(MapperatorinatorConfig.keys.gamemode), "osu!standard")
	t:eq(config:getNumber(MapperatorinatorConfig.keys.keycount), 7)
end

return test
