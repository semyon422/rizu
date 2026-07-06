local HashingTask = require("rizu.library.tasks.HashingTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local ChartmetaGenerator = require("rizu.library.generators.ChartmetaGenerator")
local ChartdiffGenerator = require("rizu.library.generators.ChartdiffGenerator")
local DifficultyModel = require("chart.difficulty.DifficultyModel")
local FakeFilesystem = require("fs.FakeFilesystem")
local digest = require("digest")

local test = {}

local function setup_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

function test.processChartfile(t)
	local db = setup_db()
	local chartfilesRepo = ChartfilesRepo(db.models)
	local chartsRepo = ChartsRepo(db.models)
	local locationsRepo = LocationsRepo(db.models)

	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local set = chartfilesRepo:insertChartfileSet({
		dir = "dir", name = "set", modified_at = 0, is_file = false, location_id = 1,
	})
	local chartfile = chartfilesRepo:insertChartfile({
		name = "chart.sph", modified_at = 0, set_id = set.id,
	})
	-- Get it back through located_chartfiles to have the 'path' field
	chartfile = db.models.located_chartfiles:find({id = chartfile.id})

	local fs = FakeFilesystem()
	fs:createDirectory("dir/set")
	local content = [[
# metadata
input 4key
# notes
1000 =0
1000 =1
]]
	fs:write("dir/set/chart.sph", content)
	local expected_hash = digest.hash("md5", content, true)

	-- Setup real generators
	local ChartFactory = require("chart.format.notechart.ChartFactory")
	local cmg = ChartmetaGenerator(chartsRepo, chartfilesRepo, ChartFactory)

	local difficultyModel = DifficultyModel()
	local cdg = ChartdiffGenerator(chartsRepo, difficultyModel)

	local context = FakeTaskContext()
	local task = HashingTask(fs, cmg, cdg, context)

	local ok, err = task:processChartfile(chartfile, nil)
	t:assert(ok, err)

	-- Verify results in DB
	local updated_cf = chartfilesRepo:selectChartfileById(chartfile.id)
	t:eq(updated_cf.hash, expected_hash)

	local meta = chartsRepo:getChartmetaByHashIndex(expected_hash, 1)
	t:assert(meta)
	t:eq(meta.inputmode, "4key")

	local diff = chartsRepo:selectDefaultChartdiff(expected_hash, 1)
	t:assert(diff)
	t:ne(diff.enps_diff, 0)

	db:unload()
end

---@param t testing.T
function test.read_error(t)
	local fs = FakeFilesystem() -- Empty filesystem

	local context = FakeTaskContext()
	-- Generators don't matter for read error
	local task = HashingTask(fs, {}, {}, context)
	-- Use a table that matches located_chartfiles structure
	local chartfile = {path = "non-existent"}
	local ok, err = task:processChartfile(chartfile, nil)

	t:ne(ok, true)
	t:assert(err:match("read error") and true)
	t:eq(#context.actions, 1)
	t:eq(context.actions[1][1], "addError")
end

function test.malformed_chart(t)
	local db = setup_db()
	local chartfilesRepo = ChartfilesRepo(db.models)
	local chartsRepo = ChartsRepo(db.models)

	local locationsRepo = LocationsRepo(db.models)
	locationsRepo:insertLocation({id = 1, path = "prefix", name = "test", is_relative = false, is_internal = false})

	local set = chartfilesRepo:insertChartfileSet({
		dir = "dir", name = "set", modified_at = 0, is_file = false, location_id = 1,
	})
	local chartfile = chartfilesRepo:insertChartfile({
		name = "bad.sph", modified_at = 0, set_id = set.id,
	})
	-- Get it back through located_chartfiles to have the 'path' field
	chartfile = db.models.located_chartfiles:find({id = chartfile.id})

	local fs = FakeFilesystem()
	fs:createDirectory("dir/set")
	fs:write("dir/set/bad.sph", "this is not an SPH file")

	local ChartFactory = require("chart.format.notechart.ChartFactory")
	local cmg = ChartmetaGenerator(chartsRepo, chartfilesRepo, ChartFactory)
	local difficultyModel = DifficultyModel()
	local cdg = ChartdiffGenerator(chartsRepo, difficultyModel)

	local context = FakeTaskContext()
	local task = HashingTask(fs, cmg, cdg, context)

	local ok, err = task:processChartfile(chartfile, nil)

	t:eq(ok, nil)
	t:assert(err)

	t:eq(#context.actions, 1)
	t:eq(context.actions[1][1], "addError")
	t:assert(context.actions[1][2]:match("chartmeta error"))

	db:unload()
end

return test
