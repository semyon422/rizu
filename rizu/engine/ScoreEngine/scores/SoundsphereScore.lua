local normalscore = require("chart.scoring.normalscore3")
local erfunc = require("chart.scoring.erfunc")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local Timings = require("sea.chart.Timings")

---Rizu's own scoring: judges, normalscore accuracy and score, and the default healths.
---Healths start half full, a hit gives 1, a miss takes a 20th of the bar, empty stays empty.
---@class rizu.SoundsphereScore: rizu.ScoreSystem, rizu.SimpleJudgesSource, rizu.IAccuracySource, rizu.IScoreSource, rizu.IHealthsSource
---@operator call: rizu.SoundsphereScore
local SoundsphereScore = ScoreSystem + SimpleJudgesSource + IAccuracySource + IScoreSource + IHealthsSource

SoundsphereScore.judge_names = {"perfect", "good", "miss"}

SoundsphereScore.accuracy_multiplier = 1000
SoundsphereScore.accuracy_format = "%0.02fms"
SoundsphereScore.score_multiplier = 10000

SoundsphereScore.max_healths = 1000

local windows = {0.016, 0.120, 0.160}

-- Misses in a row that empty a full bar.
local misses_to_fail = 20

function SoundsphereScore:new()
	self.timings = Timings("sphere")
	self.judge_windows = JudgeWindows(windows)
	self.judge_counter = JudgeCounter(3)

	self.normalscore = normalscore:new()
	self.accuracyAdjusted = 0
	self.adjustRatio = 1

	self.healths = self.max_healths / 2
end

---@return string
function SoundsphereScore:getKey()
	return "soundsphere"
end

---@param event rizu.LogicNoteChange
function SoundsphereScore:after(event)
	local ns = self.normalscore

	ns:update()

	local score_not_adjusted = math.sqrt(ns.score ^ 2 + ns.mean ^ 2)

	self.accuracy = score_not_adjusted
	self.accuracyAdjusted = ns.score
	self.adjustRatio = ns.score / score_not_adjusted
end

function SoundsphereScore:getAccuracy()
	return self.accuracyAdjusted
end

function SoundsphereScore:getScore()
	return self:getScoreForWindow(0.032)
end

---@param w number
---@return number
function SoundsphereScore:getScoreForWindow(w)
	return erfunc.erf(w / ((self.accuracyAdjusted or math.huge) * math.sqrt(2)))
end

function SoundsphereScore:getScoreString()
	return ("%d"):format(self:getScore() * self.score_multiplier)
end

---@return number
function SoundsphereScore:getHealths()
	return self.healths
end

---@return number
function SoundsphereScore:getMaxHealths()
	return self.max_healths
end

---@return boolean
function SoundsphereScore:isFailed()
	return self.healths <= 0
end

function SoundsphereScore:increaseHealths()
	if not self:isFailed() then
		self.healths = math.min(self.healths + 1, self.max_healths)
	end
end

function SoundsphereScore:decreaseHealths()
	if self:isFailed() then
		return
	end
	self.healths = self.healths - self.max_healths / misses_to_fail
	if self.healths < 1e-3 then
		self.healths = 0
	end
end

---@param event rizu.LogicNoteChange
---@param range_name string
function SoundsphereScore:hit(event, range_name)
	local index = self.judge_windows:get(event.delta_time) or -1
	self.judge_counter:add(index)
	self:setSliceJudge(event, index)
	self.normalscore:hit(range_name, event.delta_time)
	self:increaseHealths()
end

---@param event rizu.LogicNoteChange
---@param range_name string
function SoundsphereScore:miss(event, range_name)
	self.judge_counter:add(-1)
	self:setSliceJudge(event, -1)
	self.normalscore:miss(range_name)
	self:decreaseHealths()
end

-- A missed long note start has no judge of its own, the release gets it.
---@param event rizu.LogicNoteChange
function SoundsphereScore:missStart(event)
	self.normalscore:miss("LongNoteStart")
	self:decreaseHealths()
end

---@return rizu.SoundsphereScore.Slice
function SoundsphereScore:getSlice()
	local input, judge_index = self:takeSliceJudge()
	---@class rizu.SoundsphereScore.Slice
	local t = {
		input = input,
		judge_index = judge_index,
		last_judge = self:getLastJudge(),
		accuracyAdjusted = self.accuracyAdjusted,
		mean = self.normalscore.mean,
		score = self:getScore(),
		healths = self:getHealths(),
		max_healths = self:getMaxHealths(),
	}
	return t
end

---@param range_name string
---@return fun(self: rizu.SoundsphereScore, event: rizu.LogicNoteChange)
local function hit(range_name)
	return function(self, event) self:hit(event, range_name) end
end

---@param range_name string
---@return fun(self: rizu.SoundsphereScore, event: rizu.LogicNoteChange)
local function miss(range_name)
	return function(self, event) self:miss(event, range_name) end
end

SoundsphereScore.events = {
	tap = {
		clear = {
			passed = hit("ShortNote"),
			missed = miss("ShortNote"),
			clear = nil,
		},
	},
	hold = {
		clear = {
			startPassedPressed = hit("LongNoteStart"),
			startMissed = "missStart",
			startMissedPressed = "missStart",
			clear = nil,
		},
		startPassedPressed = {
			startMissed = nil,
			endMissed = miss("LongNoteEnd"),
			endPassed = hit("LongNoteEnd"),
		},
		startMissedPressed = {
			endMissedPassed = hit("LongNoteEnd"),
			startMissed = nil,
			endMissed = miss("LongNoteEnd"),
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = miss("LongNoteEnd"),
		},
	},
}

return SoundsphereScore
