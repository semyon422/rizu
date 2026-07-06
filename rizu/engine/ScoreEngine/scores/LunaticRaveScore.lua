-- SOURCE: https://hitkey.nekokan.dyndns.info/diary1501.php#D150119

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local Timings = require("sea.chart.Timings")

---@class rizu.LunaticRaveScore: rizu.ScoreSystem, rizu.SimpleJudgesSource, rizu.IAccuracySource
---@operator call: rizu.LunaticRaveScore
local LunaticRaveScore = ScoreSystem + SimpleJudgesSource + IAccuracySource

LunaticRaveScore.accuracy_multiplier = 100
LunaticRaveScore.accuracy_format = "%0.02f%%"
LunaticRaveScore.judge_names = {"pgreat", "great", "good", "bad", "miss"}

local windows = {
	[0] = {0.008, 0.024, 0.040, 0.200}, -- Very hard
	[1] = {0.015, 0.030, 0.060, 0.200}, -- Hard
	[2] = {0.018, 0.040, 0.100, 0.200}, -- Normal
	[3] = {0.021, 0.060, 0.120, 0.200}, -- Easy
}

local weights = {2, 1, 0, 0}

---@param rank integer
function LunaticRaveScore:new(rank)
	self.timings = Timings("bmsrank", rank)

	self.rank = rank

	self.judge_windows = JudgeWindows(windows[rank] or windows[3])
	self.judge_accuracy = JudgeAccuracy(weights)
	self.judge_counter = JudgeCounter(5)
end

---@return string
function LunaticRaveScore:getKey()
	return "lunatic_rank" .. self.rank
end

function LunaticRaveScore:mash()
	self.judge_counter:add(-1, true)
end

function LunaticRaveScore:getAccuracy()
	return self.judge_accuracy:get(self.judge_counter.judges)
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:hit(event)
	local index = self.judge_windows:get(event.delta_time) or -1
	self.judge_counter:add(index)
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:miss(event)
	self.judge_counter:add(-1)
end

function LunaticRaveScore:getSlice()
	return {
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
	}
end

LunaticRaveScore.events = {
	tap = {
		clear = {
			passed = "hit",
			missed = "miss",
			clear = "mash",
		},
	},
	hold = {
		clear = {
			startPassedPressed = "hit",
			startMissed = "miss",
			startMissedPressed = nil,
			clear = "mash",
		},
		startPassedPressed = {
			startMissed = nil,
			endMissed = nil,
			endPassed = nil,
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

return LunaticRaveScore
