-- SOURCE: https://github.com/Quaver/Quaver.API/blob/43e800efb079e9c099315c4b365490e357e2380c/Quaver.API/Maps/Processors/Scoring/ScoreProcessorKeys.cs

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local Timings = require("sea.chart.Timings")

---@class rizu.QuaverScore :rizu.ScoreSystem, rizu.IAccuracySource, rizu.SimpleJudgesSource, rizu.IHealthsSource
---@operator call: rizu.QuaverScore
local QuaverScore = ScoreSystem + IAccuracySource + SimpleJudgesSource + IHealthsSource

QuaverScore.accuracy_multiplier = 100
QuaverScore.accuracy_format = "%0.02f%%"
QuaverScore.judge_names = {"marvelous", "perfect", "great", "good", "okay", "miss"}

local stdWindows = {0.018, 0.043, 0.076, 0.106, 0.127, 0.164}
local weights = {100, 98.25, 65, 25, -100, -50}

-- Health change by judge index, percent of 0..100. Quaver scales the first five by the chart density.
local healthWeights = {0.5, 0.4, 0.2, -3, -4.5, -6}
-- Per judge: {slope, intercept} of the multiplier by density, marvelous to okay. Miss stays flat.
local densityMultipliers = {
	{-0.14, 2.68},
	{-0.2, 3.4},
	{-0.14, 2.68},
	{0.084, -0.008},
	{0.081, 0.028},
}

---Round half to even like C# Math.Round.
---@param x number
---@return number
local function roundEven(x)
	local f = math.floor(x)
	local d = x - f
	if d == 0.5 then
		return (f % 2 == 0 and f or f + 1)
	end
	return math.floor(x + 0.5)
end

function QuaverScore:new()
	self.timings = Timings("quaver")
	self.judge_counter = JudgeCounter(6)
	self.judge_windows = JudgeWindows(stdWindows)
	self.judge_accuracy = JudgeAccuracy(weights)
	self.health = 100
	self.health_weights = healthWeights
end

---Quaver.API ScoreProcessorKeys.InitializeHealthWeighting: charts of 12 or more actions per second keep the base weights.
---shortcut: the density is judges per chart duration at rate 1, Quaver excludes breaks of 1s+ and applies the rate; use real actions when the engine knows them.
---@param info rizu.ScoreSystem.ChartInfo
function QuaverScore:loadChart(info)
	ScoreSystem.loadChart(self, info)
	local density = info.density
	self.health_weights = healthWeights
	if not density or density <= 0 or density >= 12 then
		return
	end
	density = math.max(density, 2)
	local t = {unpack(healthWeights)}
	for i, m in ipairs(densityMultipliers) do
		t[i] = roundEven((m[1] * density + m[2]) * healthWeights[i] * 100) / 100
	end
	self.health_weights = t
end

---@param index integer judge index, negative for a miss
function QuaverScore:changeHealth(index)
	if self:isFailed() then
		return
	end
	if index < 0 then
		index = #healthWeights
	end
	self.health = math.min(math.max(self.health + self.health_weights[index], 0), 100)
end

---@return number
function QuaverScore:getHealths()
	return self.health
end

---@return number
function QuaverScore:getMaxHealths()
	return 100
end

---@return boolean
function QuaverScore:isFailed()
	return self.health <= 0
end

---@return string
function QuaverScore:getKey()
	return "quaver"
end

---@param event rizu.LogicNoteChange
function QuaverScore:hit(event)
	local is_release = event.new_state == "endPassed" or event.new_state == "endMissedPassed"

	local delta_time = event.delta_time
	if is_release then
		delta_time = delta_time / 1.5
	end

	local index = self.judge_windows:get(delta_time) or -1
	-- Quaver gives no Okay on a release, the window of Good grows instead.
	if is_release and index == 5 then
		index = 4
	end
	self.judge_counter:add(index)
	self:changeHealth(index)
	self:setSliceJudge(event, index)
end

---@param event rizu.LogicNoteChange
function QuaverScore:releaseFail(event)
	self.judge_counter:add(4)
	self:changeHealth(4)
	self:setSliceJudge(event, 4)
end

---@param event rizu.LogicNoteChange
function QuaverScore:miss(event)
	self.judge_counter:add(-1)
	self:changeHealth(-1)
	self:setSliceJudge(event, -1)
end

---Quaver never shows a negative accuracy.
function QuaverScore:getAccuracy()
	return math.max(self.judge_accuracy:get(self.judge_counter.judges), 0)
end

---A long note whose head is missed costs two misses at once, the head and the tail.
---@param event rizu.LogicNoteChange
function QuaverScore:missLongNote(event)
	self:miss(event)
	self:miss(event)
end

function QuaverScore:getSlice()
	local input, judge_index = self:takeSliceJudge()
	return {
		input = input,
		judge_index = judge_index,
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
		healths = self:getHealths(),
		max_healths = self:getMaxHealths(),
	}
end

QuaverScore.events = {
	tap = {
		clear = {
			passed = "hit",
			missed = "miss",
			clear = nil,
		},
	},
	hold = {
		clear = {
			startPassedPressed = "hit",
			startMissed = "missLongNote",
			startMissedPressed = "missLongNote",
			clear = nil,
		},
		startPassedPressed = {
			startMissed = "miss",
			endMissed = "releaseFail",
			endPassed = "hit",
		},
		startMissedPressed = {
			endMissedPassed = nil,
			startMissed = nil,
			endMissed = nil,
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = nil,
		},
	},
}

return QuaverScore
