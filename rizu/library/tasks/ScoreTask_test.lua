local ScoreTask = require("rizu.library.tasks.ScoreTask")
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

function test.computeAll(t)
	local db = setup_db()
	local chartsRepo = ChartsRepo(db.models)
	local tcf = TestChartFactory()

	-- 1. Setup a chartplay that needs computation
	local chartplay = tcf:createChartplay({replay_hash = "replay1", compute_state = "new"})
	chartsRepo:createChartplay(chartplay)

	t:eq(chartsRepo:getChartplaysComputedCount(0, "new"), 1)

	local chartsComputer = {
		computeChartplay = function(_, chartplay)
			chartplay.compute_state = "valid"
			chartplay.computed_at = 0
			chartsRepo:updateChartplay(chartplay)
			return {chartplay_computed = {}}
		end,
	}

	local context = FakeTaskContext()
	local task = ScoreTask(chartsRepo, chartsComputer, context, timer)

	task:computeAll()

	-- Verify state updated in DB
	t:eq(chartsRepo:getChartplaysComputedCount(0, "new"), 0)
	local cp = chartsRepo:getChartplayByReplayHash("replay1")
	---@cast cp -?
	t:eq(cp.compute_state, "valid")

	db:unload()
end

return test
