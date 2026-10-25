local table_util = require("table_util")
local HitsTask = require("rizu.library.tasks.HitsTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local ChartplayHitsRepo = require("rizu.library.repos.ChartplayHitsRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local FakeClient = require("sea.compute.FakeClient")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local FunctionTimer = require("time.FunctionTimer")
local chart_samples = require("sea.chart.samples.Samples")

local test = {}

---@param t testing.T
function test.replays_the_plays_without_hits_once(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local chartsRepo = ChartsRepo(db.models)
	local hitsRepo = ChartplayHitsRepo(db.models)

	local sample = chart_samples[1]
	local client = FakeClient(0.02, 100)
	local play = client:play(sample.name, sample.data, 1, 100, 0)
	chartsRepo:createUpdateChartmeta(assert(play.chartmeta), 0)

	---@param fields table
	---@return sea.Chartplay
	local function create(fields)
		local values = table_util.copy(play.chartplay)
		table_util.copy({user_id = 1, compute_state = "valid", computed_at = 0, submitted_at = 0}, values)
		return chartsRepo:createChartplay(table_util.copy(fields, values))
	end
	local chartplay = create({})
	local custom = create({custom = true, replay_hash = ("0"):rep(32)})

	local replays = 0
	local loader = ComputeDataLoader({
		getChartData = function() return {name = sample.name, data = sample.data} end,
		getReplayData = function()
			replays = replays + 1
			return play.replay_data
		end,
	})
	local timer = FunctionTimer(function() return 0 end)
	local context = FakeTaskContext()
	local task = HitsTask(chartsRepo, hitsRepo, loader, context, timer)

	t:eq(task:computeMissing(), true)
	t:eq(replays, 1)
	local score_engine = assert(client.computeContext.score_engine)
	t:tdeq(hitsRepo:getHits(chartplay.id), {
		notes_count = score_engine.chartdiff.notes_count,
		inputmode = score_engine.chartdiff.inputmode,
		events = score_engine.events,
	})
	t:eq(hitsRepo:getHits(custom.id), nil)
	for _, action in ipairs(context.actions) do
		t:ne(action[1], "addError", action[2])
	end

	-- Stored ones are not played again.
	t:eq(task:computeMissing(), true)
	t:eq(replays, 1)
	db:unload()
end

return test
