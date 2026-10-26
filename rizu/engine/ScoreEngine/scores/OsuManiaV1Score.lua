-- SOURCE: https://osu.ppy.sh/wiki/en/Gameplay/Judgement/osu!mania
-- HP: osu!stable, RulesetMania_HpCalculation.CalculateHpDropRate and Ruleset.IncreaseScoreHit

local math_util = require("math_util")

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local osu_hp = require("rizu.engine.ScoreEngine.scores.osu_hp")

---@class rizu.OsuManiaV1Score: rizu.ScoreSystem, rizu.IAccuracySource, rizu.IScoreSource, rizu.SimpleJudgesSource, rizu.IHealthsSource
---@operator call: rizu.OsuManiaV1Score
---@field health number 0..200
---@field hp number HPDrainRate of the chart.
---@field hp_multiplier number
local OsuManiaV1Score = ScoreSystem + IAccuracySource + IScoreSource + SimpleJudgesSource + IHealthsSource

OsuManiaV1Score.accuracy_multiplier = 100
OsuManiaV1Score.accuracy_format = "%0.02f%%"
OsuManiaV1Score.judge_names = {"perfect", "great", "good", "ok", "meh", "miss"}

local hitBonus = {2, 1, -8, -24, -44, -56}
local hitValue = {320, 300, 200, 100, 50, 0}
local hitBonusValue = {32, 32, 16, 8, 4, 0}
local weights = {300, 300, 200, 100, 50, 0}

local hp_max = 200
-- shortcut: stable's PreEmpt depends on the scroll speed, which is not known here; use a typical value.
local pre_empt = 1000

---@param judge integer
---@param hp number
---@param multiplier number
---@return number
local function healthIncrease(judge, hp, multiplier)
	if judge == 1 then
		return multiplier * (1.1 - hp * 0.1)
	elseif judge == 2 then
		return multiplier * (1 - hp * 0.1)
	elseif judge == 3 then
		return multiplier * (0.8 - hp * 0.08)
	elseif judge == 4 then
		return 0
	elseif judge == 5 then
		return -(hp + 1) * 0.32
	end
	return -(hp + 1) * 1.5
end

---Port of RulesetMania.CalculateHpDropRate, mania never applies the drain and keeps the multiplier of normal hits.
---shortcut: breaks of the chart are not known here, stable skips them in the drain; add them when the chart has breaks.
---@param objects {[1]: number, [2]: number}[] start and end in milliseconds, sorted by start
---@param hp number
---@return number
local function computeHpMultiplier(objects, hp)
	if #objects == 0 then
		return 1
	end

	local lowest_ever = osu_hp.range(hp, 195, 160, 60)
	local lowest_end = osu_hp.range(hp, 198, 180, 80)
	local recovery_available = osu_hp.range(hp, 8, 4, 0)

	local multiplier = 1 ---@type number
	local test_drop = 0.05

	while true do
		local current = hp_max ---@type number
		local uncapped = hp_max ---@type number
		local last_time = objects[1][1] - pre_empt
		local fail = false

		for _, o in ipairs(objects) do
			local drop = test_drop * (o[1] - last_time)
			uncapped = math.max(0, uncapped - drop)
			current = math.max(0, current - drop)
			last_time = o[2]

			if current <= lowest_ever then
				fail = true
				test_drop = test_drop * 0.96
				break
			end

			local increase = healthIncrease(1, hp, multiplier)
			uncapped = uncapped + increase
			current = math.min(hp_max, current + increase)
		end

		if not fail and current < lowest_end then
			fail = true
			test_drop = test_drop * 0.94
			multiplier = multiplier * 1.01
		end

		if not fail and (uncapped - hp_max) / #objects < recovery_available then
			fail = true
			test_drop = test_drop * 0.96
			multiplier = multiplier * 1.01
		end

		if not fail then
			return multiplier
		end
	end
end

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

	---@type {[integer]: rizu.OsuManiaV1Score.LongNoteState}
	self.pressedLongNotes = {}

	self.baseScore = 0
	self.bonusScore = 0
	self.score = 0

	self.bonus = 100
	self.hitValue = 0
	self.totalBonus = 0
	self.combo = 0

	self.health = hp_max
	self.hp = 5
	self.hp_multiplier = 1
end

---@param info rizu.ScoreSystem.ChartInfo
function OsuManiaV1Score:load(info)
	ScoreSystem.load(self, info)
	self.hp = osu_hp.getDrainRate(info.healths)
	self.hp_multiplier = computeHpMultiplier(osu_hp.getObjects(info.chart), self.hp)
end

---@return string
function OsuManiaV1Score:getKey()
	return "osu_mania_v1_od" .. self.od
end

---@param index integer
---@param event rizu.LogicNoteChange?
function OsuManiaV1Score:addCounter(index, event)
	self.judge_counter:add(index)
	if event then
		self:setSliceJudge(event, index)
	end
	self.last_judge = index
	self.visual_judge = index

	if not self:isFailed() then
		self.health = math.min(math.max(self.health + healthIncrease(index, self.hp, self.hp_multiplier), 0), hp_max)
	end

	self.hitValue = self.hitValue + hitValue[index]
	-- stable assigns the miss penalty instead of adding it, so a miss empties the meter.
	self.bonus = math_util.clamp((index == 6 and 0 or self.bonus) + hitBonus[index], 0, 100)

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
	self:takeSliceJudge()
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
	self:addCounter(6, event)
	if event.type == "hold" then
		self:setLongNoteState(event, nil)
	end
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:shortNoteHit(event)
	local index = self.note_judge_windows:get(event.delta_time) or 6
	self:addCounter(index, event)
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:longNoteStartHit(event)
	-- osu! judges an LN once, at its end. The head timing is retained only for
	-- the combined head+tail judgement; it must not add a separate judgement.
	-- Its head judgement is nevertheless exposed for visual hit feedback.
	local index = self.head_judge_windows:get(event.delta_time) or 6
	self.visual_judge = index
	self:setSliceJudge(event, index)
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
		self:addCounter(6, event)
		return
	end

	-- Releasing before the 50 window is a stable hold break and final miss.
	if event.delta_time < -self.windows[5] then
		self:addCounter(6, event)
	else
		self:addCounter(self:getLongNoteJudge(state.head_delta_time, event.delta_time), event)
	end
	self:setLongNoteState(event, nil)
end

---@param event rizu.LogicNoteChange
function OsuManiaV1Score:longNoteFail(event)
	local state = self:getLongNoteState(event)
	if state then
		-- Stable measures a broken LN from the latest re-press.
		state.broken = true
		-- A hold break is a zero-score miss in stable: it breaks combo right away.
		self.combo = 0
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
		self:addCounter(6, event)
		return
	end

	local index = self:getLongNoteJudge(state.head_delta_time, event.delta_time)
	if state.broken then
		-- In stable, a hold break caps an otherwise 300g/300 LN at 200.
		index = math.max(index, 3)
	end
	self:addCounter(index, event)
	self:setLongNoteState(event, nil)
end

function OsuManiaV1Score:getScore()
	return self.score
end

---@return number
function OsuManiaV1Score:getHealths()
	return self.health / 2
end

---@return number
function OsuManiaV1Score:getMaxHealths()
	return 100
end

---@return boolean
function OsuManiaV1Score:isFailed()
	return self.health <= 0
end

function OsuManiaV1Score:getAccuracy()
	return self.judge_accuracy:get(self.judge_counter.judges)
end

function OsuManiaV1Score:getSlice()
	local input, judge_index = self:takeSliceJudge()
	return {
		input = input,
		judge_index = judge_index,
		accuracy = self:getAccuracy(),
		last_judge = self:getLastJudge(), -- scoring judgement, only assigned at an LN tail
		visual_judge = self:getVisualJudge(), -- immediate head/tail feedback for UI
		score = self:getScore(),
		healths = self:getHealths(),
		max_healths = self:getMaxHealths(),
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
