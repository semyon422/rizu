local class = require("class")
local valid = require("valid")
local table_util = require("table_util")
local Chartplay = require("sea.chart.Chartplay")
local ReplayFactory = require("rizu.engine.replay.ReplayFactory")
local ChartplayComputedFactory = require("rizu.engine.ChartplayComputedFactory")

---@class rizu.ScoreSaver
---@operator call: rizu.ScoreSaver
local ScoreSaver = class()

---@param fs fs.IFilesystem
---@param library rizu.library.Library
---@param configModel sphere.ConfigModel
---@param seaClient rizu.SeaClient
---@param replayBase sea.ReplayBase
---@param computeContext sea.ComputeContext
function ScoreSaver:new(
	fs,
	library,
	configModel,
	seaClient,
	replayBase,
	computeContext
)
	self.fs = fs
	self.library = library
	self.configModel = configModel
	self.seaClient = seaClient
	self.replayBase = replayBase
	self.computeContext = computeContext

	self.replay_factory = ReplayFactory()
end

---@param gameplay_session rizu.GameplaySession
function ScoreSaver:saveScore(gameplay_session)
	local rhythm_engine = gameplay_session.rhythm_engine
	local pause_counter = rhythm_engine.pause_counter
	local scoreEngine = rhythm_engine.score_engine
	local replayBase = self.replayBase
	local computeContext = self.computeContext

	local chartmeta = assert(computeContext.chartmeta)
	local created_at = os.time()

	local replay, data, replay_hash = self.replay_factory:createReplay(
		replayBase,
		chartmeta,
		gameplay_session.replay_recorder:getFrames(),
		created_at,
		pause_counter.count
	)

	self.fs:write("userdata/replays/" .. replay_hash, data)

	local chartdiff = assert(computeContext.chartdiff)
	local chartdiff_copy = setmetatable(table_util.deepcopy(chartdiff), getmetatable(chartdiff))

	chartdiff = self.library.chartsRepo:createUpdateChartdiff(chartdiff, created_at)

	local chartplay = Chartplay()

	local cc_factory = ChartplayComputedFactory(chartdiff, computeContext.diffcalc_context, scoreEngine)
	local chartplay_computed = cc_factory:getChartplayComputed()

	chartplay:importChartplayBase(replay)
	chartplay:importChartplayComputed(chartplay_computed)

	chartplay.hash = chartmeta.hash
	chartplay.index = chartmeta.index

	chartplay.replay_hash = replay_hash
	chartplay.pause_count = pause_counter.count
	chartplay.created_at = created_at

	assert(valid.format(chartplay:validate()))
	local chartplay_copy = setmetatable(table_util.deepcopy(chartplay), Chartplay)

	chartplay.user_id = 1
	chartplay.compute_state = "valid"
	chartplay.computed_at = created_at
	chartplay.submitted_at = created_at

	local _chartplay = self.library.chartsRepo:createChartplay(chartplay)
	computeContext.chartplay = _chartplay

	local function submit()
		if not self.seaClient.connected then
			return
		end

		local base = scoreEngine.scores.base
		if base.hitCount / base.notes_count < 0.5 then
			print("not submitted")
			return
		end

		print("submit")
		local submission, err = self.seaClient.remote.submission:submitChartplay(chartplay_copy, chartdiff_copy)
		print("got", submission, err)
		if submission then
			print(require("stbl").encode(submission))
		else
			print("dumping events")
			local data = require("string.buffer").encode(rhythm_engine.score_engine.events)
			self.fs:write("events.bin", data)
		end
	end

	coroutine.wrap(function()
		local ok, err = xpcall(submit, debug.traceback)
		if not ok then
			print("submit error", err)
		end
	end)()

	local config = self.configModel.configs.select
	config.selected_chartplay_id = config.chartplay_id
	config.chartplay_id = _chartplay.id
end

return ScoreSaver
