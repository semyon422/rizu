local class = require("class")
local Observable = require("Observable")
local ScoreEngine = require("sphere.models.RhythmModel.ScoreEngine")
local LogicEngine = require("sphere.models.RhythmModel.LogicEngine")
local GraphicEngine = require("sphere.models.RhythmModel.GraphicEngine")
local AudioEngine = require("sphere.models.RhythmModel.AudioEngine")
local TimeEngine = require("sphere.models.RhythmModel.TimeEngine")
local InputManager = require("sphere.models.RhythmModel.InputManager")
local PauseCounter = require("sphere.models.RhythmModel.PauseCounter")
local ChartplayComputed = require("sea.chart.ChartplayComputed")
local Timings = require("sea.chart.Timings")
local osu_pp = require("chart.scoring.osu_pp")
local minacalc = require("chart.scoring.minacalc")
-- require("sphere.models.RhythmModel.LogicEngine.Test")

---@class sphere.RhythmModel
---@operator call: sphere.RhythmModel
local RhythmModel = class()

---@param inputModel sphere.InputModel
---@param resourceModel sphere.ResourceModel
function RhythmModel:new(inputModel, resourceModel)
	self.inputModel = inputModel
	self.resourceModel = resourceModel

	self.timeEngine = TimeEngine()
	self.inputManager = InputManager(self.timeEngine, inputModel)
	self.scoreEngine = ScoreEngine()
	self.audioEngine = AudioEngine(self.timeEngine, resourceModel)
	self.logicEngine = LogicEngine(self.timeEngine, self.scoreEngine)
	self.graphicEngine = GraphicEngine(self.timeEngine.visualTimeInfo, self.logicEngine)
	self.pauseCounter = PauseCounter(self.timeEngine)
	self.observable = Observable()

	self.timeEngine.audioEngine = self.audioEngine
	self.timeEngine.logicEngine = self.logicEngine

	self.inputManager.observable:add(self.logicEngine)
	self.inputManager.observable:add(self.observable)

	self.logicEngine.observable:add(self.audioEngine)
end

function RhythmModel:loadAllEngines()
	self:loadLogicEngines()
	self.audioEngine:load()
	self.graphicEngine:load()
end

function RhythmModel:loadLogicEngines()
	self.timeEngine:load()
	self.scoreEngine:load()
	self.pauseCounter:load()
	self.logicEngine:load()
end

function RhythmModel:unloadAllEngines()
	self.audioEngine:unload()
	self.logicEngine:unload()
	self.graphicEngine:unload()

	-- for _, column in self.chart:iterLayerNotes() do
		-- self.observable:send({
		-- 	name = "keyreleased",
		-- 	virtual = true,
		-- 	inputType .. inputIndex
		-- })
	-- end
end

function RhythmModel:unloadLogicEngines()
	self.scoreEngine:unload()
	self.logicEngine:unload()
end

function RhythmModel:play()
	self.timeEngine:play()
	self.audioEngine:play()
	self.inputManager:loadState()
end

function RhythmModel:pause()
	self.timeEngine:pause()
	self.audioEngine:pause()
	self.inputManager:saveState()
end

---@param event table
function RhythmModel:receive(event)
	if event.name == "framestarted" then
		self.timeEngine:sync(event.time)
		return
	end

	self.inputManager:receive(event)
end

function RhythmModel:update()
	if self.timeEngine.timer.is_playing then
		self.logicEngine:update()
	end
	self.audioEngine:update()
	self.pauseCounter:update()
	self.graphicEngine:update()
end

---@return boolean
function RhythmModel:hasResult()
	local timeEngine = self.timeEngine
	local base = self.scoreEngine.scores.base
	local accuracy = self.scoreEngine.scores.normalscore.accuracyAdjusted

	return
		not self.logicEngine.autoplay and
		not self.logicEngine.promode and
		not self.timeEngine.windUp and
		timeEngine.currentTime >= timeEngine.minTime and
		base.hitCount > 0 and
		accuracy > 0 and
		accuracy < math.huge
end

---@param fast boolean?
function RhythmModel:getChartplayComputed(fast)
	local chartdiff = self.chartdiff
	if not chartdiff then
		return ChartplayComputed()
	end

	local scoreEngine = self.scoreEngine
	local scores = scoreEngine.scores
	local judgesSource = assert(scoreEngine.judgesSource)

	-- scoreEngine:createByTimings(Timings("etternaj", 4))

	-- local j4 = scoreEngine:getScoreSystem("etterna_accuracy_j4")
	-- ---@cast j4 sphere.EtternaAccuracy

	local ns_score = scores.normalscore:getScore()
	-- print(ns_score, scores.normalscore:getScoreForWindow(0.040), j4:getAccuracyString())

	local rating_msd = 0
	if not fast then
		local ctx = self.diffcalc_context
		local ssr = minacalc.calc_ssr(ctx:getSimplifiedNotes(), ctx.chart.inputMode:getColumns(), ctx.rate, ns_score)
		rating_msd = ssr.overall
	end

	local c = ChartplayComputed()
	c.pass = not scores.hp:isFailed()
	c.judges = judgesSource:getJudges()
	c.accuracy = scores.normalscore.accuracyAdjusted
	c.max_combo = scores.base.maxCombo
	c.miss_count = scores.base.missCount
	c.not_perfect_count = judgesSource:getNotPerfect()
	c.rating = ns_score * chartdiff.enps_diff
	c.rating_pp = osu_pp.calc_no_acc(ns_score, chartdiff.osu_diff, chartdiff.notes_count)
	c.rating_msd = rating_msd

	return c
end

---@param replayBase sea.ReplayBase
function RhythmModel:setReplayBase(replayBase)
	self.replayBase = replayBase
	self.logicEngine.timings = replayBase.timing_values
	self.logicEngine.nearest = replayBase.nearest
	self.timeEngine:setBaseTimeRate(replayBase.rate)
	self.graphicEngine.constant = replayBase.const
	self.timeEngine.constant = replayBase.const
	self.logicEngine.singleHandler = replayBase.mode == "taiko"
end

---@param windUp table?
function RhythmModel:setWindUp(windUp)
	self.timeEngine.windUp = windUp
end

---@param autoplay boolean
function RhythmModel:setAutoplay(autoplay)
	self.logicEngine.autoplay = autoplay
end

---@param promode boolean
function RhythmModel:setPromode(promode)
	self.logicEngine.promode = promode
end

---@param adjustRate number
function RhythmModel:setAdjustRate(adjustRate)
	self.timeEngine.adjustRate = adjustRate
end

---@param chart ncdk2.Chart
---@param chartmeta sea.Chartmeta
---@param chartdiff sea.Chartdiff
---@param diffcalc_context sphere.DiffcalcContext
function RhythmModel:setNoteChart(chart, chartmeta, chartdiff, diffcalc_context)
	assert(chart)
	self.chart = chart
	self.chartmeta = chartmeta
	self.chartdiff = chartdiff
	self.diffcalc_context = diffcalc_context
	self.timeEngine.noteChart = chart
	self.scoreEngine.noteChart = chart
	self.scoreEngine.chartdiff = chartdiff
	self.logicEngine:setChart(chart)
	self.graphicEngine:setChart(chart)
	self.audioEngine.format = chartmeta.format
end

---@param start_time number
---@param duration number
function RhythmModel:setPlayTime(start_time, duration)
	self.timeEngine:setPlayTime(start_time, duration)
	self.pauseCounter:setPlayTime(start_time, duration)
end

---@param range table
function RhythmModel:setDrawRange(range)
	self.graphicEngine.range = range
end

---@param volume table
function RhythmModel:setVolume(volume)
	self.audioEngine.volume = volume
	self.audioEngine:updateVolume()
end

---@param mode table
function RhythmModel:setAudioMode(mode)
	self.audioEngine.mode = mode
end

---@param visualTimeRate number
function RhythmModel:setVisualTimeRate(visualTimeRate)
	self.graphicEngine.visualTimeRate = visualTimeRate
	self.graphicEngine.targetVisualTimeRate = visualTimeRate
end

---@param judgement_name string
---@param rating_hit_window number
function RhythmModel:setScoring(judgement_name, rating_hit_window)
	self.scoreEngine.judgement = judgement_name
	self.scoreEngine.ratingHitWindow = rating_hit_window
end

---@param longNoteShortening number
function RhythmModel:setLongNoteShortening(longNoteShortening)
	self.graphicEngine.longNoteShortening = longNoteShortening
end

---@param timeToPrepare number
function RhythmModel:setTimeToPrepare(timeToPrepare)
	self.timeEngine.timeToPrepare = timeToPrepare
end

---@param offset number
function RhythmModel:setInputOffset(offset)
	self.logicEngine.inputOffset = math.floor(offset * 1024) / 1024
end

---@param offset number
function RhythmModel:setVisualOffset(offset)
	self.graphicEngine.visualOffset = offset
end

---@param scaleSpeed boolean
function RhythmModel:setVisualTimeRateScale(scaleSpeed)
	self.graphicEngine.scaleSpeed = scaleSpeed
end

return RhythmModel
