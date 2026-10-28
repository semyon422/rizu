-- SOURCE: https://iidx.org/compendium/gauges_and_timing
-- SOURCE: https://iidx.org/compendium/exscore

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IComboSource = require("rizu.engine.ScoreEngine.IComboSource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local Timings = require("sea.chart.Timings")

---@class rizu.IidxScore: rizu.ScoreSystem, rizu.SimpleJudgesSource, rizu.IAccuracySource, rizu.IComboSource, rizu.IScoreSource, rizu.IHealthsSource
---@operator call: rizu.IidxScore
---@field chart_notes_count integer
local IidxScore = ScoreSystem + SimpleJudgesSource + IAccuracySource + IComboSource + IScoreSource + IHealthsSource

IidxScore.accuracy_multiplier = 100
IidxScore.accuracy_format = "%0.02f%%"
IidxScore.judge_names = {"pgreat", "great", "good", "bad", "poor"}

-- Continuous-time thresholds in seconds. Input timestamps are not quantized.
-- Excessive-POOR windows are not publicly known and are not implemented here.
local windows = {0.01667, 0.03333, 0.11667, 0.25000}
local charge_tail_window = 0.11667

-- SOURCE: https://iidx.org/misc/iidx_lr2_beatoraja_diff
-- Gauge changes by judge index: pgreat, great, good, bad, poor, then an empty poor. Percent of 0..100.
-- Scaled gains are the "a" value times these. `low_life` halves bad and poor damage at 30% and below.
---@alias rizu.IidxScore.Rules {gain: number[], damage: number[], start: number, survival: boolean, scaled: boolean?, low_life: boolean?, clear: number?}
---@type {[integer]: rizu.IidxScore.Rules}
local gauge_rules = {
	[0] = {gain = {1, 1, 0.5}, damage = {-1.6, -4.8, -1.6}, start = 22, survival = false, scaled = true, clear = 60}, -- assist easy
	[1] = {gain = {1, 1, 0.5}, damage = {-1.6, -4.8, -1.6}, start = 22, survival = false, scaled = true, clear = 80}, -- easy
	[2] = {gain = {1, 1, 0.5}, damage = {-2, -6, -2}, start = 22, survival = false, scaled = true, clear = 80}, -- normal
	[3] = {gain = {0.16, 0.16, 0}, damage = {-5, -9, -5}, start = 100, survival = true, low_life = true}, -- hard
	[4] = {gain = {0.16, 0.16, 0}, damage = {-10, -18, -10}, start = 100, survival = true}, -- ex-hard
}

---@param gauge integer? 0 assist easy, 1 easy, 2 normal, 3 hard, 4 ex-hard. Normal when nil.
function IidxScore:new(gauge)
	self.timings = Timings("iidx")

	self.gauge = gauge or 2
	self.rules = gauge_rules[self.gauge]
	self.health = self.rules.start
	self.failed = false
	self.chart_notes_count = 0
	self.judge_windows = JudgeWindows(windows)
	self.judge_counter = JudgeCounter(5)
	self.combo = 0
	self.max_combo = 0

	---@type {[integer]: boolean}
	self.active_charge_notes = {}
end

---@return string
function IidxScore:getKey()
	return "iidx" .. (self.gauge ~= 2 and "_g" .. self.gauge or "")
end

---@param info rizu.ScoreSystem.ChartInfo
function IidxScore:load(info)
	ScoreSystem.load(self, info)
	self.chart_notes_count = info.notes_count
	self.health = self.rules.start
end

---shortcut: the real IIDX "a" curve is unpublished, this is the standard BMS #TOTAL curve per note, replace when known.
---@return number
function IidxScore:getGainPerNote()
	local notes = math.max(self.chart_notes_count, 1)
	return 7.605 / (0.01 * notes + 6.5)
end

---@param judge integer 1..5
function IidxScore:changeHealth(judge)
	if self.failed then
		return
	end
	local rules = self.rules
	local delta ---@type number
	if judge <= 3 then
		delta = rules.gain[judge]
		if rules.scaled then
			delta = delta * self:getGainPerNote()
		end
	else
		delta = rules.damage[judge - 3]
		if rules.low_life and self.health <= 30 then
			delta = delta / 2
		end
	end
	self.health = self.health + delta

	if rules.survival then
		if self.health <= 0 then
			self.failed = true
		end
	else
		self.health = math.max(self.health, 2)
	end
	self.health = math.min(math.max(self.health, 0), 100)
end

---@return number
function IidxScore:getHealths()
	return self.health
end

---@return number
function IidxScore:getMaxHealths()
	return 100
end

---@return boolean
function IidxScore:isFailed()
	return self.failed
end

---@return boolean
function IidxScore:isPassed()
	if self.rules.survival then
		return not self.failed
	end
	return self.health >= self.rules.clear
end

---@param index integer
---@param event rizu.LogicNoteChange?
function IidxScore:addJudge(index, event)
	self.judge_counter:add(index)
	self:changeHealth(index)
	if event then
		self:setSliceJudge(event, index)
	end
	if index <= 3 then
		self.combo = self.combo + 1
		self.max_combo = math.max(self.max_combo, self.combo)
	else
		self.combo = 0
	end
end

---@param event rizu.LogicNoteChange
function IidxScore:hit(event)
	self:addJudge(self.judge_windows:get(event.delta_time) or 5, event)
end

---@param event rizu.LogicNoteChange
function IidxScore:miss(event)
	self:addJudge(5, event)
end

---@param event rizu.LogicNoteChange
function IidxScore:chargeHead(event)
	local index = self.judge_windows:get(event.delta_time) or 5
	self:addJudge(index, event)
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
		self:addJudge(1, event) -- Any valid release is PGREAT.
	elseif delta_time < 0 then
		self:addJudge(5, event) -- Premature release is POOR.
	else
		self:addJudge(4, event) -- Holding past the late boundary is BAD.
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
	local input, judge_index = self:takeSliceJudge()
	return {
		input = input,
		judge_index = judge_index,
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
		score = self:getScore(),
		combo = self:getCombo(),
		max_combo = self:getMaxCombo(),
		healths = self:getHealths(),
		max_healths = self:getMaxHealths(),
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
