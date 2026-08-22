local class = require("class")
local valid = require("valid")
local table_util = require("table_util")
local delay = require("delay")
local string_buffer = require("string.buffer")
local Chartplay = require("sea.chart.Chartplay")
local ReplayFactory = require("rizu.engine.replay.ReplayFactory")
local ChartplayComputedFactory = require("rizu.engine.ChartplayComputedFactory")
local ScoreSubmissionLog = require("rizu.gameplay.ScoreSubmissionLog")

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
	self.submission_log = ScoreSubmissionLog(fs)

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

	---@param event string
	---@param fields {[string]: any}?
	local function log(event, fields)
		fields = fields or {}
		fields.replay_hash = replay_hash
		fields.chart_hash = chartmeta.hash
		fields.chart_index = chartmeta.index
		self.submission_log:write(event, fields)
	end

	---@param submission_status sea.ComputeJobStatus
	local function trackSubmission(submission_status)
		local deadline = os.time() + 600
		local previous_state = submission_status.state
		local previous_attempt_count = submission_status.attempt_count
		while submission_status.state == "queued" or submission_status.state == "running"
			or submission_status.state == "succeeded" and not submission_status.effects_complete
		do
			if os.time() >= deadline then
				log("tracking_timeout", {job_id = submission_status.job_id, state = submission_status.state})
				return
			end
			delay.sleep(2)
			if not self.seaClient.connected then
				log("tracking_interrupted", {job_id = submission_status.job_id, reason = "disconnected"})
				return
			end
			local next_status, err = self.seaClient.remote.submission:getChartplaySubmission(submission_status.job_id)
			if not next_status then
				log("status_failed", {job_id = submission_status.job_id, error = err or "unknown error"})
				return
			end
			submission_status = next_status
			if submission_status.state ~= previous_state or submission_status.attempt_count ~= previous_attempt_count then
				log("status", {
					job_id = submission_status.job_id,
					state = submission_status.state,
					attempt_count = submission_status.attempt_count,
					max_attempts = submission_status.max_attempts,
					error_kind = submission_status.last_error_kind,
					error_code = submission_status.last_error_code,
					error = submission_status.last_error_message,
				})
				previous_state = submission_status.state
				previous_attempt_count = submission_status.attempt_count
			end
		end

		if submission_status.state == "succeeded" then
			log("completed", {
				job_id = submission_status.job_id,
				chartplay_id = submission_status.chartplay_id,
				effects_complete = submission_status.effects_complete,
			})
		else
			log("failed", {
				job_id = submission_status.job_id,
				state = submission_status.state,
				attempt_count = submission_status.attempt_count,
				error_kind = submission_status.last_error_kind,
				error_code = submission_status.last_error_code,
				error = submission_status.last_error_message,
			})
		end
	end

	local function submit()
		if not self.seaClient.connected then
			log("skipped", {reason = "not_connected"})
			return
		end

		local base = scoreEngine.scores.base
		local hit_ratio = base.hitCount / base.notes_count
		if hit_ratio < 0.5 then
			log("skipped", {reason = "hit_ratio_below_threshold", hit_ratio = hit_ratio})
			return
		end

		log("started", {hit_ratio = hit_ratio})
		local submission, err = self.seaClient.remote.submission:submitChartplay(chartplay_copy, chartdiff_copy)
		if submission then
			local status = submission.status
			log("accepted", {
				job_id = status.job_id,
				chartplay_id = status.chartplay_id,
				state = status.state,
				attempt_count = status.attempt_count,
				max_attempts = status.max_attempts,
				duplicate = submission.duplicate,
			})
			trackSubmission(status)
			return
		end

		log("rejected", {error = err or "unknown error"})
		local events_data = string_buffer.encode(rhythm_engine.score_engine.events)
		local events_path = "userdata/logs/score_submission_" .. replay_hash .. ".events"
		local ok, write_err = self.fs:write(events_path, events_data)
		if not ok then
			log("event_dump_failed", {error = write_err or "unknown error", path = events_path})
		else
			log("event_dumped", {path = events_path})
		end
	end

	coroutine.wrap(function()
		local ok, err = xpcall(submit, debug.traceback)
		if not ok then
			log("exception", {error = err})
		end
	end)()

	local config = self.configModel.configs.select
	config.selected_chartplay_id = config.chartplay_id
	config.chartplay_id = _chartplay.id
end

return ScoreSaver
