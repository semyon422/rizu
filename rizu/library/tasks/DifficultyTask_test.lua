local DifficultyTask = require("rizu.library.tasks.DifficultyTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")
local FunctionTimer = require("time.FunctionTimer")

local test = {}
local timer = FunctionTimer(function()
	return 0
end)

local function setup_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	return db
end

function test.computeMissing(t)
	local db = setup_db()
	local chartsRepo = ChartsRepo(db.models, {"enps_diff"})

	local tcf = TestChartFactory()
	local res = tcf:create("4key", {
		{time = 0, column = 1},
		{time = 1, column = 2},
	})

	local hash = "test_hash"
	res.chartmeta.hash = hash
	res.chartmeta.created_at = 0
	res.chartmeta.computed_at = 0
	chartsRepo:createChartmeta(res.chartmeta)

	-- Verify it shows up as missing
	local missing = chartsRepo:getChartmetasMissingChartdiffs()
	t:eq(#missing, 1)

	local difficultyModel = {
		compute = function(_, diff, chart, rate)
			diff.enps_diff = 10.0
		end,
	}

	local chartdiffGenerator = {
		compute = function(_, chart, rate)
			local d = res.chartdiff
			d.rate = rate
			difficultyModel:compute(d, chart, rate)
			return d
		end,
	}

	local context = FakeTaskContext()
	context.charts[hash] = {res.chart}

	local task = DifficultyTask(difficultyModel, chartdiffGenerator, chartsRepo, context, timer, function(hash)
		return context:getChartsByHash(hash)
	end)

	task:computeMissing()

	-- Verify diff was created
	local diff = chartsRepo:selectDefaultChartdiff(hash, 1)
	t:assert(diff)
	t:eq(diff.enps_diff, 10.0)

	-- Verify missing is now empty
	missing = chartsRepo:getChartmetasMissingChartdiffs()
	t:eq(#missing, 0)

	db:unload()
end

function test.cancellation(t)
	local db = setup_db()
	local chartsRepo = ChartsRepo(db.models, {"enps_diff"})

	local tcf = TestChartFactory()

	-- Setup 5 charts
	for i = 1, 5 do
		local res = tcf:create("4key", {{time = 0, column = 1}})
		res.chartmeta.hash = "hash" .. i
		res.chartmeta.created_at = 0
		res.chartmeta.computed_at = 0
		chartsRepo:createChartmeta(res.chartmeta)
	end

	local difficultyModel = {compute = function() end}
	local chartdiffGenerator = {
		compute = function(_, _, rate)
			local res = tcf:create("4key", {{time = 0, column = 1}})
			res.chartdiff.rate = rate
			return res.chartdiff
		end,
	}

	local context = FakeTaskContext()
	-- Return true for shouldStop after 2 items
	local calls = 0
	function context:shouldStop()
		calls = calls + 1
		return calls > 2
	end

	context.getChartsByHash = function()
		return {{index = 1, layers = {main = {toAbsolute = function() end}}, inputMode = "4key"}}
	end

	local task = DifficultyTask(difficultyModel, chartdiffGenerator, chartsRepo, context, timer, function(hash)
		return context:getChartsByHash(hash)
	end)
	task:computeMissing()

	-- Should have processed only 2 charts because check happens at start of loop
	-- and we return true on 3rd call.
	-- Let's check DB.
	local count = chartsRepo:countChartdiffs()
	t:eq(count, 2, "Should have only 2 diffs created before cancellation")

	db:unload()
end

return test
