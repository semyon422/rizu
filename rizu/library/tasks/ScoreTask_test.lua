local ScoreTask = require("rizu.library.tasks.ScoreTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")
local FunctionTimer = require("time.FunctionTimer")
local table_util = require("table_util")
local ChartplayHitsRepo = require("rizu.library.repos.ChartplayHitsRepo")
local ChartsComputer = require("sea.compute.ChartsComputer")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local ComputeVersion = require("sea.compute.ComputeVersion")
local ReplayComputer = require("sea.compute.ReplayComputer")
local FakeClient = require("sea.compute.FakeClient")
local chart_samples = require("sea.chart.samples.Samples")

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
	local task = ScoreTask(chartsRepo, chartsComputer, ChartplayHitsRepo(db.models), context, timer)

	task:computeAll()

	-- Verify state updated in DB
	t:eq(chartsRepo:getChartplaysComputedCount(0, "new"), 0)
	local cp = chartsRepo:getChartplayByReplayHash("replay1")
	---@cast cp -?
	t:eq(cp.compute_state, "valid")

	db:unload()
end

---@param t testing.T
function test.recompute_all_updates_old_scores_and_stores_hits(t)
	local db = setup_db()
	local chartsRepo = ChartsRepo(db.models)
	local hitsRepo = ChartplayHitsRepo(db.models)

	local sample = chart_samples[1]
	local client = FakeClient(0.02, 100)
	local play = client:play(sample.name, sample.data, 1, 100, 0)
	chartsRepo:createUpdateChartmeta(assert(play.chartmeta), 0)

	-- Computed long ago, its rating lost since.
	local values = table_util.copy(play.chartplay)
	table_util.copy({user_id = 1, compute_state = "valid", computed_at = 0, submitted_at = 0, rating = 0}, values)
	local chartplay = chartsRepo:createChartplay(values)

	local loader = ComputeDataLoader({
		getChartData = function() return {name = sample.name, data = sample.data} end,
		getReplayData = function() return play.replay_data end,
	})
	local chartsComputer = ChartsComputer(loader, chartsRepo, ReplayComputer(), ComputeVersion.current())
	local context = FakeTaskContext()
	local task = ScoreTask(chartsRepo, chartsComputer, hitsRepo, context, timer)

	-- Computed after the run began: done already.
	t:eq(task:recomputeAll(0), true)
	t:assert(not hitsRepo:getHits(chartplay.id))

	t:eq(task:recomputeAll(1), true)

	for _, action in ipairs(context.actions) do
		t:ne(action[1], "addError", action[2])
	end
	local cp = assert(chartsRepo:getChartplayByReplayHash(chartplay.replay_hash))
	t:eq(cp.compute_state, "valid")
	t:assert(cp.rating > 0, "rating")
	t:assert(hitsRepo:getHits(chartplay.id))

	db:unload()
end

return test
