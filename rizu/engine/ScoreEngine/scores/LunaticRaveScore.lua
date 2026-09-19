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
local Timings = require("sea.chart.Timings")

---@class rizu.LunaticRaveScore: rizu.ScoreSystem, rizu.SimpleJudgesSource, rizu.IAccuracySource, rizu.IComboSource, rizu.IScoreSource
---@operator call: rizu.LunaticRaveScore
local LunaticRaveScore = ScoreSystem + SimpleJudgesSource + IAccuracySource + IComboSource + IScoreSource

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

---@param rank integer
function LunaticRaveScore:new(rank)
	self.timings = Timings("bmsrank", rank)

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
	return "lunatic_rank" .. self.rank
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:mash(event)
	-- LR2 accepts an early POOR only during the one-second window before a note.
	-- Judge 0 neither consumes that note nor breaks combo.
	if event.delta_time > -1 then
		self.judge_counter:add(-1, true)
	end
end

---@param index integer
function LunaticRaveScore:addJudge(index)
	self.judge_counter:add(index)
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
	self:addJudge(index)
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:miss(event)
	self:addJudge(5)
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

	self:addJudge(index)
	self.long_note_judges[event.index] = nil
end

---@param event rizu.LogicNoteChange
function LunaticRaveScore:longNoteTimeout(event)
	local index = self.long_note_judges[event.index]
	if not index then
		return
	end

	self:addJudge(index)
	self.long_note_judges[event.index] = nil
end

function LunaticRaveScore:getSlice()
	return {
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(),
		score = self:getScore(),
		ex_score = self:getExScore(),
		combo = self:getCombo(),
		max_combo = self:getMaxCombo(),
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
