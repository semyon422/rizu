-- SOURCE: https://github.com/Quaver/Quaver.API/blob/43e800efb079e9c099315c4b365490e357e2380c/Quaver.API/Maps/Processors/Scoring/ScoreProcessorKeys.cs

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local Timings = require("sea.chart.Timings")

---@class rizu.QuaverScore :rizu.ScoreSystem, rizu.IAccuracySource, rizu.SimpleJudgesSource
---@operator call: rizu.QuaverScore
local QuaverScore = ScoreSystem + IAccuracySource + SimpleJudgesSource

QuaverScore.accuracy_multiplier = 100
QuaverScore.accuracy_format = "%0.02f%%"
QuaverScore.judge_names = {"marvelous", "perfect", "great", "good", "okay", "miss"}

local stdWindows = {0.018, 0.043, 0.076, 0.106, 0.127, 0.164}
local weights = {100, 98.25, 65, 25, -100, -50}

function QuaverScore:new()
	self.timings = Timings("quaver")
	self.judge_counter = JudgeCounter(6)
	self.judge_windows = JudgeWindows(stdWindows)
	self.judge_accuracy = JudgeAccuracy(weights)
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
	self.judge_counter:add(index)
end

function QuaverScore:releaseFail()
	self.judge_counter:add(4)
end

function QuaverScore:miss()
	self.judge_counter:add(-1)
end

function QuaverScore:getAccuracy()
	return self.judge_accuracy:get(self.judge_counter.judges)
end

function QuaverScore:getSlice()
	return {
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
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
			startMissed = "miss",
			startMissedPressed = "miss",
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
			endMissed = "miss",
		},
	},
}

return QuaverScore
