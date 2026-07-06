--- SOURCE: https://github.com/etternagame/etterna
--- SOURCE: https://github.com/etternagame/etterna/blob/master/Themes/_fallback/Scripts/10%20Scores.lua

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local Timings = require("sea.chart.Timings")

local judgeTimingWindows = {
	{0.03375, 0.0675, 0.135, 0.2025, 0.27},
	{0.029925, 0.05985, 0.1197, 0.17955, 0.2394},
	{0.0261, 0.0522, 0.1044, 0.1566, 0.2088},
	{0.0225, 0.045, 0.09, 0.135, 0.18},
	{0.0189, 0.0378, 0.0756, 0.1134, 0.18},
	{0.01485, 0.0297, 0.0594, 0.0891, 0.18},
	{0.01125, 0.0225, 0.045, 0.0675, 0.18},
	{0.007425, 0.01485, 0.0297, 0.04455, 0.18},
	{0.0045, 0.009, 0.018, 0.027, 0.18},
}

---@class rizu.EtternaJudges: rizu.ScoreSystem, rizu.SimpleJudgesSource
---@operator call: rizu.EtternaJudges
local EtternaJudges = ScoreSystem + SimpleJudgesSource

EtternaJudges.judge_names = {"marvelous", "perfect", "great", "bad", "boo", "miss"}

---@param j number
function EtternaJudges:new(j)
	self.timings = Timings("etternaj", j)

	self.judge = j

	local w = judgeTimingWindows[j]
	local windows = {
		w[1],
		w[2],
		w[3],
		w[4],
		w[5],
	}

	self.judge_windows = JudgeWindows(windows)
	self.judge_counter = JudgeCounter(6)
end

---@return string
function EtternaJudges:getKey()
	return "etterna_judges_j" .. self.judge
end

---@param event rizu.LogicNoteChange
function EtternaJudges:hit(event)
	local index = self.judge_windows:get(event.delta_time) or -1
	self.judge_counter:add(index)
end

function EtternaJudges:miss()
	self.judge_counter:add(-1)
end

function EtternaJudges:getSlice()
	return {
		last_judge = self:getLastJudge(),
	}
end

EtternaJudges.events = {
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
			startMissedPressed = nil,
			clear = nil,
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

return EtternaJudges
