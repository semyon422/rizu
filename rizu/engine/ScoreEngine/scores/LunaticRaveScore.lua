-- SOURCE: https://hitkey.nekokan.dyndns.info/diary1501.php#D150119
-- SOURCE 2: https://github.com/GOMazk/OpenLR2

-- TODO: LR2 early POOR behavior for long-note heads is not implemented correctly.
-- In LR2, pressing an LN head outside the BAD window but within the one-second
-- early-POOR window adds a POOR without consuming the LN. The same head can
-- still be pressed again later and receive its normal deferred LN judgment.
-- Rizu currently changes the HoldLogicNote state to startMissedPressed, and this
-- scorer records a regular miss that consumes the LN's scoring opportunity.
-- Implement this by giving HoldLogicNote a non-consuming early-press transition
-- (equivalent to tap clear -> clear), dispatching it to mash(), and keeping the
-- LN in clear so a later valid head press can start the deferred LN judgment.

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IComboSource = require("rizu.engine.ScoreEngine.IComboSource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local Timings = require("sea.chart.Timings")

---@class rizu.LunaticRaveScore: rizu.ScoreSystem, rizu.SimpleJudgesSource, rizu.IAccuracySource, rizu.IComboSource, rizu.IScoreSource, rizu.IHealthsSource
---@operator call: rizu.LunaticRaveScore
local LunaticRaveScore = ScoreSystem + SimpleJudgesSource + IAccuracySource + IComboSource + IScoreSource + IHealthsSource

LunaticRaveScore.accuracy_multiplier = 100
LunaticRaveScore.accuracy_format = "%0.02f%%"
LunaticRaveScore.judge_names = {"pgreat", "great", "good", "bad", "miss"}

local windows = {
	[0] = {0.008, 0.024, 0.040, 0.200}, -- Very hard
	[1] = {0.015, 0.030, 0.060, 0.200}, -- Hard
	[2] = {0.018, 0.040, 0.100, 0.200}, -- Normal
	[3] = {0.021, 0.060, 0.120, 0.200}, -- Easy
}
windows[4] = windows[2] -- Invalid #RANK uses LR2's default (Normal) windows


-- SOURCE: judge_damage of LR2_bmsload.cpp and the update in Scene04_Play.cpp of https://github.com/GOMazk/OpenLR2
-- Gauge changes by judge index: pgreat, great, good, bad, poor, then an empty poor (mash). Percent of 0..100.
-- groove and easy gain `total / notes` times these, the rest are flat. Hard's damage scales by the hard multiplier.
---@type {[integer]: {gain: number[], damage: number[], start: number, survival: boolean}}
local gauge_rules = {
	[0] = {gain = {1, 1, 0.5}, damage = {-4, -6, -2}, start = 20, survival = false},
	[1] = {gain = {1.2, 1.2, 0.6}, damage = {-3.2, -4.8, -1.6}, start = 20, survival = false},
	[2] = {gain = {0.1, 0.1, 0.05}, damage = {-6, -10, -2}, start = 100, survival = true},
	[3] = {gain = {0, 0, 0}, damage = {-100, -100, 0}, start = 100, survival = true},
}

---Hard gauge damage multiplier: bigger for charts with few notes or a low #TOTAL.
---SOURCE: GAS::GetHealthMultiplier of https://github.com/aeventyr/LR2GAS_pub, the same as LR2_bmsload.cpp of OpenLR2
---@param notes integer
---@param total number
---@return number
local function getHardMultiplier(notes, total)
	local by_notes ---@type number
	if notes < 20 then
		by_notes = 10
	elseif notes < 30 then
		by_notes = 14 - notes / 5
	elseif notes < 60 then
		by_notes = 9 - notes / 15
	elseif notes < 125 then
		by_notes = 5 - (notes - 60) / 65
	elseif notes < 250 then
		by_notes = 5 - notes / 125
	elseif notes < 500 then
		by_notes = 4 - notes / 250
	elseif notes < 1000 then
		by_notes = 3 - notes / 500
	else
		by_notes = 1
	end
	local total_steps = math.min(10, math.max(1, math.floor((total - 80) / 16)))
	return math.max(10 / total_steps, by_notes)
end

---@param rank integer
---@param gauge integer? 0 groove, 1 easy, 2 hard, 3 hazard. Groove when nil.
function LunaticRaveScore:new(rank, gauge)
	self.timings = Timings("bmsrank", rank)

	self.gauge = gauge or 0
	self.rules = gauge_rules[self.gauge]
	self.health = self.rules.start
	self.failed = false

	self.rank = rank

	self.windows = windows[rank] or windows[2]
	self.judge_windows = JudgeWindows(self.windows)
	self.judge_counter = JudgeCounter(5)
	self.combo = 0
	self.max_combo = 0

	---@type {[integer]: integer}
	self.long_note_judges = {}
end

---@return string
function LunaticRaveScore:getKey()
	return "lunatic_rank" .. self.rank .. (self.gauge ~= 0 and "_g" .. self.gauge or "")
end

---A chart without #TOTAL gets a value from its notes count.
---SOURCE: calculateDefaultTotal of https://github.com/seraxis/lr2oraja-endlessdream, BMSPlayerRule.java,
---which gives the same values as the `total[p] < 1` branch of LR2_bmsload.cpp of OpenLR2.
---@return number
function LunaticRaveScore:getTotal()
	local healths = self.chart_healths
	if healths and healths.name == "bmstotal" then
		return healths.data
	end
	local notes = self.notes_count
	return 160 + (notes + math.min(math.max(notes - 400, 0), 200)) * 0.16
end

---@param judge integer 1..5, 6 for an empty poor.
function LunaticRaveScore:changeHealth(judge)
	if self.failed then
		return
	end
	local rules = self.rules
	local delta ---@type number
	if judge <= 3 then
		delta = rules.gain[judge]
		if self.gauge <= 1 then
			delta = delta * self:getTotal() / math.max(self.notes_count, 1)
		end
	else
		-- bad, poor, empty poor
		delta = rules.damage[judge - 3]
		if self.gauge == 2 then
			delta = delta * getHardMultiplier(self.notes_count, self:getTotal())
		end
		-- Hard and hazard hurt less at low gauge, LR2 compares the even-rounded integer part.
		if self.gauge ~= 0 and self.gauge ~= 1 and math.floor(math.floor(self.health) / 2) * 2 <= 30 then
			delta = delta * 0.6
		end
	end
	self.health = self.health + delta

	-- LR2 keeps a gauge of exactly 2 alive, it fails below.
	if self.health < 2 then
		if rules.survival then
			self.failed = true
		else
			self.health = 2
		end
	end
	self.health = math.min(math.max(self.health, 0), 100)
end

---@return number
function LunaticRaveScore:getHealths()
	return self.health
end

---@return number
function LunaticRaveScore:getMaxHealths()
	return 100
end

---Groove and easy never die.
---@return boolean
function LunaticRaveScore:isFailed()
	return self.failed
end

---Groove and easy clear with 80% at the end of the chart.
---@return boolean
function LunaticRaveScore:isPassed()
	if self.rules.survival then
		return not self.failed
	end
	return self.health >= 80
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:mash(event)
	-- LR2 accepts an early POOR only during the one-second window before a note.
	-- Judge 0 neither consumes that note nor breaks combo.
	if event.delta_time > -1 then
		self.judge_counter:add(-1, true)
		self:changeHealth(6)
	end
end

---@param index integer
---@param event rizu.LogicNoteChange?
function LunaticRaveScore:addJudge(index, event)
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

---@return integer
function LunaticRaveScore:getCombo()
	return self.combo
end

---@return integer
function LunaticRaveScore:getMaxCombo()
	return self.max_combo
end

function LunaticRaveScore:getAccuracy()
	local judged_notes = self.judge_counter.total
	if judged_notes == 0 then
		return 0
	end

	local judges = self.judge_counter.judges
	return (judges[1] * 2 + judges[2]) / (judged_notes * 2)
end

---@return integer
function LunaticRaveScore:getExScore()
	local judges = self.judge_counter.judges
	return judges[1] * 2 + judges[2]
end

---@return number
function LunaticRaveScore:getScore()
	if self.notes_count == 0 then
		return 0
	end

	local judges = self.judge_counter.judges
	local pgreat, great, good = judges[1], judges[2], judges[3]
	return math.floor((good + great * 2 + pgreat * 4) * 50000 / self.notes_count)
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:hit(event)
	local index = self.judge_windows:get(event.delta_time) or 5
	self:addJudge(index, event)
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:miss(event)
	self:addJudge(5, event)
	self.long_note_judges[event.index] = nil
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:longNoteStart(event)
	-- LR2 retains the head judgment and scores the LN only when it ends.
	self.long_note_judges[event.index] = self.judge_windows:get(event.delta_time) or 5
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:longNoteRelease(event)
	local index = self.long_note_judges[event.index]
	if not index then
		return
	end

	-- Releasing more than a GOOD window before the tail forces BAD.
	if event.delta_time < -self.windows[3] then
		index = 4
	end

	self:addJudge(index, event)
	self.long_note_judges[event.index] = nil
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:longNoteTimeout(event)
	local index = self.long_note_judges[event.index]
	if not index then
		return
	end

	self:addJudge(index, event)
	self.long_note_judges[event.index] = nil
end

function LunaticRaveScore:getSlice()
	local input, judge_index = self:takeSliceJudge()
	return {
		input = input,
		judge_index = judge_index,
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
		score = self:getScore(),
		ex_score = self:getExScore(),
		combo = self:getCombo(),
		max_combo = self:getMaxCombo(),
		healths = self:getHealths(),
		max_healths = self:getMaxHealths(),
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
			startPassedPressed = "longNoteStart",
			startMissed = "miss",
			startMissedPressed = "miss",
			clear = "mash",
		},
		startPassedPressed = {
			startMissed = "longNoteRelease",
			endMissed = "longNoteTimeout",
			endPassed = "longNoteRelease",
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
