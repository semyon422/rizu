local normalscore = require("chart.scoring.normalscore3")
local erfunc = require("chart.scoring.erfunc")
local ScoreSystem = require("sphere.models.RhythmModel.ScoreEngine.ScoreSystem")
local IAccuracySource = require("sphere.models.RhythmModel.ScoreEngine.IAccuracySource")
local IScoreSource = require("sphere.models.RhythmModel.ScoreEngine.IScoreSource")

---@class sphere.NormalscoreScore: sphere.ScoreSystem, sphere.IAccuracySource, sphere.IScoreSource
---@operator call: sphere.NormalscoreScore
local NormalscoreScore = ScoreSystem + IAccuracySource + IScoreSource

NormalscoreScore.accuracy_multiplier = 1000
NormalscoreScore.accuracy_format = "%0.02fms"
NormalscoreScore.score_multiplier = 10000

function NormalscoreScore:new()
	self.normalscore = normalscore:new()
	self.accuracyAdjusted = 0
	self.adjustRatio = 1
end

---@return string
function NormalscoreScore:getKey()
	return "normalscore"
end

---@param event rizu.LogicNoteChange
function NormalscoreScore:after(event)
	local ns = self.normalscore

	ns:update()

	local score_not_adjusted = math.sqrt(ns.score ^ 2 + ns.mean ^ 2)

	self.accuracy = score_not_adjusted
	self.accuracyAdjusted = ns.score
	self.adjustRatio = ns.score / score_not_adjusted
end

function NormalscoreScore:getAccuracy()
	return self.accuracyAdjusted
end

function NormalscoreScore:getScore()
	return self:getScoreForWindow(0.032)
end

---@param w number
---@return number
function NormalscoreScore:getScoreForWindow(w)
	return erfunc.erf(w / ((self.accuracyAdjusted or math.huge) * math.sqrt(2)))
end

function NormalscoreScore:getScoreString()
	return ("%d"):format(self:getScore() * self.score_multiplier)
end

---@param range_name string
---@param deltaTime number
function NormalscoreScore:hit(range_name, deltaTime)
	self.normalscore:hit(range_name, deltaTime)
end

---@param range_name string
function NormalscoreScore:miss(range_name)
	self.normalscore:miss(range_name)
end

---@return sphere.NormalscoreScore.Slice
function NormalscoreScore:getSlice()
	---@class sphere.NormalscoreScore.Slice
	local t = {
		accuracyAdjusted = self.accuracyAdjusted,
		mean = self.normalscore.mean
	}
	return t
end

NormalscoreScore.events = {
	tap = {
		clear = {
			passed = function(self, event) self:hit("ShortNote", event.delta_time) end,
			missed = function(self) self:miss("ShortNote") end,
		},
	},
	hold = {
		clear = {
			startPassedPressed = function(self, event) self:hit("LongNoteStart", event.delta_time) end,
			startMissed = function(self) self:miss("LongNoteStart") end,
			startMissedPressed = function(self) self:miss("LongNoteStart") end,
		},
		startPassedPressed = {
			startMissed = nil,
			endMissed = function(self) self:miss("LongNoteEnd") end,
			endPassed = function(self, event) self:hit("LongNoteEnd", event.delta_time) end,
		},
		startMissedPressed = {
			endMissedPassed = function(self, event) self:hit("LongNoteEnd", event.delta_time) end,
			startMissed = nil,
			endMissed = function(self) self:miss("LongNoteEnd") end,
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = function(self) self:miss("LongNoteEnd") end,
		},
	},
}

return NormalscoreScore
