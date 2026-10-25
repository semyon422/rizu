local table_util = require("table_util")
local AccuracyTask = require("rizu.library.tasks.AccuracyTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local ChartplayAccuraciesRepo = require("rizu.library.repos.ChartplayAccuraciesRepo")
local StoredAccuracies = require("rizu.engine.ScoreEngine.StoredAccuracies")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local FakeClient = require("sea.compute.FakeClient")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local FunctionTimer = require("time.FunctionTimer")
local chart_samples = require("sea.chart.samples.Samples")

local test = {}

---@param t testing.T
function test.replays_plays_and_skips_custom_ones(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local chartsRepo = ChartsRepo(db.models)
	local accuraciesRepo = ChartplayAccuraciesRepo(db.models)

	local sample = chart_samples[1]
	local client = FakeClient(0.02, 100)
	local play = client:play(sample.name, sample.data, 1, 100, 0)

	---@param fields table
	---@return sea.Chartplay
	local function create(fields)
		local values = table_util.copy(play.chartplay)
		table_util.copy({user_id = 1, compute_state = "valid", computed_at = 0, submitted_at = 0}, values)
		return chartsRepo:createChartplay(table_util.copy(fields, values))
	end
	local chartplay = create({})
	local custom = create({custom = true, replay_hash = ("0"):rep(32)})
	accuraciesRepo:setAccuracies(custom.id, {{timings = 2304, subtimings = 0, accuracy = 0.5}})

	local loader = ComputeDataLoader({
		getChartData = function() return {name = sample.name, data = sample.data} end,
		getReplayData = function() return play.replay_data end,
	})
	local timer = FunctionTimer(function() return 0 end)
	local context = FakeTaskContext()
	AccuracyTask(chartsRepo, accuraciesRepo, loader, context, timer):computeAll("auto,osuod:9:1,etternaj:4")

	local tokens = StoredAccuracies.parse("auto,osuod:9:1,etternaj:4")
	local expected = StoredAccuracies.compute(assert(client.computeContext.score_engine), tokens, play.chartmeta.timings)
	t:assert(#expected >= 2)
	local rows = accuraciesRepo:getAccuracies(chartplay.id)
	t:eq(#rows, #expected)
	for i, row in ipairs(expected) do
		t:eq(rows[i].timings, row.timings)
		t:eq(rows[i].accuracy, row.accuracy)
	end
	t:eq(accuraciesRepo:getAccuracies(custom.id)[1].accuracy, 0.5)

	for _, action in ipairs(context.actions) do
		t:ne(action[1], "addError", action[2])
	end
	db:unload()
end

return test
