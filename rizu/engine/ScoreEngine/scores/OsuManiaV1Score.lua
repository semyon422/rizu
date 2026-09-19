-- SOURCE: https://osu.ppy.sh/wiki/en/Gameplay/Judgement/osu!mania

local math_util = require("math_util")

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

---@class rizu.OsuManiaV1Score: rizu.ScoreSystem, rizu.IAccuracySource, rizu.IScoreSource, rizu.SimpleJudgesSource
---@operator call: rizu.OsuManiaV1Score
local OsuManiaV1Score = ScoreSystem + IAccuracySource + IScoreSource + SimpleJudgesSource

OsuManiaV1Score.accuracy_multiplier = 100
OsuManiaV1Score.accuracy_format = "%0.02f%%"
OsuManiaV1Score.judge_names = {"perfect", "great", "good", "ok", "meh", "miss"}

local hitBonus = {2, 1, -8, -24, -44, -56}
local hitValue = {320, 300, 200, 100, 50, 0}
local hitBonusValue = {32, 32, 16, 8, 4, 0}
local weights = {300, 300, 200, 100, 50, 0}

---@param od number
function OsuManiaV1Score:new(od)
	self.timings = Timings("osuod", od)
	self.subtimings = Subtimings("scorev", 1)

	self.od = od

	self.judge_accuracy = JudgeAccuracy(weights)
	self.judge_counter = JudgeCounter(6)

	local od3 = 3 * od

	self.windows = {
		16 / 1000,
		(64 - od3) / 1000,
		(97 - od3) / 1000,
		(127 - od3) / 1000,
		(151 - od3) / 1000,
		(188 - od3) / 1000,
	}
	self.note_judge_windows = JudgeWindows(self.windows)
	self.judge_windows = self.note_judge_windows

	local w = self.windows

	self.headWindows = {
		w[1] * 1.2,
		w[2] * 1.1,
		w[3],
		w[4],
		w[5],
		w[6],
	}
	self.head_judge_windows = JudgeWindows(self.headWindows)

	self.tailWindows = {
		w[1] * 2.4,
		w[2] * 2.2,
		w[3] * 2,
		w[4] * 2,
		w[5],
		w[6],
	}
	self.tail_judge_windows = JudgeWindows(self.tailWindows)

	---@type {[integer]: integer}
	self.pressedLongNotes = {}

	self.baseScore = 0
	self.bonusScore = 0
	self.score = 0

	self.bonus = 100
	self.hitValue = 0
	self.totalBonus = 0
	self.combo = 0
end

---@return string
function OsuManiaV1Score:getKey()
	return "osu_mania_v1_od" .. self.od
end

---@param index integer
function OsuManiaV1Score:addCounter(index)
	self.judge_counter:add(index)
	self.last_judge = index
	self.visual_judge = index

	self.hitValue = self.hitValue + hitValue[index]
	self.bonus = math_util.clamp(self.bonus + hitBonus[index], 0, 100)

	-- osu!stable restores the bonus meter before a judgement at each 384 combo.
	if self.combo ~= 0 and self.combo % 384 == 0 then
		self.bonus = 100
	end
	self.totalBonus = self.totalBonus + (hitBonusValue[index] * math.sqrt(self.bonus) / 320)

	if index == 6 then
		self.combo = 0
	else
		self.combo = self.combo + 1
	end

	self.baseScore = (500000 / self.notes_count) * (self.hitValue / 320)
	self.bonusScore = (500000 / self.notes_count) * self.totalBonus

	-- stable truncates displayed score after every scoring event.
	self.score = math.floor(self.baseScore + self.bonusScore)
end

---@param event rizu.LogicNoteChange
---@return rizu.OsuManiaV1Score.LongNoteState?
function OsuManiaV1Score:getLongNoteState(event)
	return self.pressedLongNotes[event.index]
end

---@param event rizu.LogicNoteChange
---@param state rizu.OsuManiaV1Score.LongNoteState?
function OsuManiaV1Score:setLongNoteState(event, state)
	self.pressedLongNotes[event.index] = state
end

---@class rizu.OsuManiaV1Score.LongNoteState
---@field head_delta_time number
---@field broken boolean
---@field tail_missed boolean

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:before(event)
	-- An LN head has timing data but stable does not judge it until its tail.
	-- Do not let views reuse the preceding note's judgement for this event.
	self.last_judge = nil
	self.visual_judge = nil
end

---@return integer?
function OsuManiaV1Score:getLastJudge()
	return self.last_judge
end

---@return integer?
function OsuManiaV1Score:getVisualJudge()
	return self.visual_judge
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:miss(event)
	self:addCounter(6)
	if event.type == "hold" then
		self:setLongNoteState(event, nil)
	end
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:shortNoteHit(event)
	local index = self.note_judge_windows:get(event.delta_time) or 6
	self:addCounter(index)
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:longNoteStartHit(event)
	-- osu! judges an LN once, at its end. The head timing is retained only for
	-- the combined head+tail judgement; it must not add a separate judgement.
	-- Its head judgement is nevertheless exposed for visual hit feedback.
	self.visual_judge = self.head_judge_windows:get(event.delta_time) or 6
	self:setLongNoteState(event, {
		head_delta_time = event.delta_time,
		broken = false,
		tail_missed = false,
	})
end

---@param head_delta_time number
---@param tail_delta_time number
---@return integer
function OsuManiaV1Score:getLongNoteJudge(head_delta_time, tail_delta_time)
	local head = math.abs(head_delta_time)
	local total = head + math.abs(tail_delta_time)
	local w = self.windows

	if head <= w[1] * 1.2 and total <= w[1] * 2.4 then
		return 1
	elseif head <= w[2] * 1.1 and total <= w[2] * 2.2 then
		return 2
	elseif head <= w[3] and total <= w[3] * 2 then
		return 3
	elseif head <= w[4] and total <= w[4] * 2 then
		return 4
	end
	return 5
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:didntReleased(event)
	local state = self:getLongNoteState(event)
	if not state then
		self:addCounter(6)
		return
	end

	-- Releasing before the 50 window is a stable hold break and final miss.
	if event.delta_time < -self.windows[5] then
		self:addCounter(6)
	else
		self:addCounter(self:getLongNoteJudge(state.head_delta_time, event.delta_time))
	end
	self:setLongNoteState(event, nil)
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:longNoteFail(event)
	local state = self:getLongNoteState(event)
	if state then
		-- Stable measures a broken LN from the latest re-press.
		state.broken = true
		state.head_delta_time = event.press_delta_time or state.head_delta_time
		return
	end

	-- Stable retains an out-of-window head press for its combined tail result.
	self:setLongNoteState(event, {
		head_delta_time = event.press_delta_time or math.huge,
		broken = false,
		tail_missed = false,
	})
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:longNoteRelease(event)
	local state = self:getLongNoteState(event)
	if not state then
		self:addCounter(6)
		return
	end

	local index = self:getLongNoteJudge(state.head_delta_time, event.delta_time)
	if state.broken then
		-- In stable, a hold break caps an otherwise 300g/300 LN at 200.
		index = math.max(index, 3)
	end
	self:addCounter(index)
	self:setLongNoteState(event, nil)
end

function OsuManiaV1Score:getScore()
	return self.score
end

function OsuManiaV1Score:getAccuracy()
	return self.judge_accuracy:get(self.judge_counter.judges)
end

function OsuManiaV1Score:getSlice()
	return {
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(), -- scoring judgement, only assigned at an LN tail
		visual_judge = self:getVisualJudge(), -- immediate head/tail feedback for UI
		score = self:getScore(),
	}
end

OsuManiaV1Score.events = {
	tap = {
		clear = {
			passed = "shortNoteHit",
			missed = "miss",
			clear = nil,
		},
	},
	hold = {
		clear = {
			startPassedPressed = "longNoteStartHit",
			startMissed = "longNoteFail",
			startMissedPressed = "longNoteFail",
			clear = nil,
		},
		startPassedPressed = {
			startMissed = "longNoteFail",
			endMissed = "didntReleased",
			endPassed = "longNoteRelease",
		},
		startMissedPressed = {
			endMissedPassed = "longNoteRelease",
			startMissed = "longNoteFail",
			endMissed = "didntReleased",
		},
		startMissed = {
			startMissedPressed = "longNoteFail",
			endMissed = "miss",
		},
	},
}

return OsuManiaV1Score
