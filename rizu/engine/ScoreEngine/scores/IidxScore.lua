-- SOURCE: https://iidx.org/compendium/gauges_and_timing
-- SOURCE: https://iidx.org/compendium/exscore

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IComboSource = require("rizu.engine.ScoreEngine.IComboSource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local Timings = require("sea.chart.Timings")

---@class rizu.IidxScore: rizu.ScoreSystem, rizu.SimpleJudgesSource, rizu.IAccuracySource, rizu.IComboSource, rizu.IScoreSource
---@operator call: rizu.IidxScore
local IidxScore = ScoreSystem + SimpleJudgesSource + IAccuracySource + IComboSource + IScoreSource

IidxScore.accuracy_multiplier = 100
IidxScore.accuracy_format = "%0.02f%%"
IidxScore.judge_names = {"pgreat", "great", "good", "bad", "poor"}

-- Continuous-time thresholds in seconds. Input timestamps are not quantized.
-- Excessive-POOR windows are not publicly known and are not implemented here.
local windows = {0.01667, 0.03333, 0.11667, 0.25000}
local charge_tail_window = 0.11667

function IidxScore:new()
	self.timings = Timings("iidx")
	self.judge_windows = JudgeWindows(windows)
	self.judge_counter = JudgeCounter(5)
	self.combo = 0
	self.max_combo = 0

	---@type {[integer]: boolean}
	self.active_charge_notes = {}
end

---@return string
function IidxScore:getKey()
	return "iidx"
end

---@param index integer
function IidxScore:addJudge(index)
	self.judge_counter:add(index)
	if index <= 3 then
		self.combo = self.combo + 1
		self.max_combo = math.max(self.max_combo, self.combo)
	else
		self.combo = 0
	end
end

---@param event rizu.LogicNoteChange
function IidxScore:hit(event)
	self:addJudge(self.judge_windows:get(event.delta_time) or 5)
end

function IidxScore:miss()
	self:addJudge(5)
end

---@param event rizu.LogicNoteChange
function IidxScore:chargeHead(event)
	local index = self.judge_windows:get(event.delta_time) or 5
	self:addJudge(index)
	-- A BAD or POOR head deactivates the tail judgment.
	self.active_charge_notes[event.index] = index <= 3 or nil
end

---@param event rizu.LogicNoteChange
function IidxScore:chargeTail(event)
	if not self.active_charge_notes[event.index] then
		return
	end

	local delta_time = event.delta_time
	if math.abs(delta_time) <= charge_tail_window then
		self:addJudge(1) -- Any valid release is PGREAT.
	elseif delta_time < 0 then
		self:addJudge(5) -- Premature release is POOR.
	else
		self:addJudge(4) -- Holding past the late boundary is BAD.
	end
	self.active_charge_notes[event.index] = nil
end

---@return integer
function IidxScore:getScore()
	local judges = self.judge_counter.judges
	return judges[1] * 2 + judges[2]
end

---@return number
function IidxScore:getAccuracy()
	local total = self.judge_counter.total
	if total == 0 then
		return 0
	end
	return self:getScore() / (total * 2)
end

---@return integer
function IidxScore:getCombo()
	return self.combo
end

---@return integer
function IidxScore:getMaxCombo()
	return self.max_combo
end

function IidxScore:getSlice()
	return {
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
		score = self:getScore(),
		combo = self:getCombo(),
		max_combo = self:getMaxCombo(),
	}
end

IidxScore.events = {
	tap = {
		clear = {
			passed = "hit",
			missed = "miss",
			clear = nil, -- exact excessive-POOR windows are unknown
		},
	},
	hold = {
		clear = {
			startPassedPressed = "chargeHead",
			startMissed = "miss",
			startMissedPressed = "miss",
			clear = nil,
		},
		startPassedPressed = {
			startMissed = "chargeTail",
			endMissed = "chargeTail",
			endPassed = "chargeTail",
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

return IidxScore
