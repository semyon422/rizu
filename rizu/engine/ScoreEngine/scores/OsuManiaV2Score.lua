-- SOURCE: https://osu.ppy.sh/wiki/en/Gameplay/Judgement/osu!mania
-- HP and score: osu!lazer, ManiaHealthProcessor, LegacyDrainingHealthProcessor and ManiaScoreProcessor

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local IHealthsSource = require("rizu.engine.ScoreEngine.IHealthsSource")
local IScoreSource = require("rizu.engine.ScoreEngine.IScoreSource")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local OsuManiaV2Timings = require("sea.timings.osumania.OsuManiaV2Timings_v2")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

---@class rizu.OsuManiaV2Score: rizu.ScoreSystem, rizu.IAccuracySource, rizu.SimpleJudgesSource, rizu.IHealthsSource, rizu.IScoreSource
---@operator call: rizu.OsuManiaV2Score
---@field health number 0..100
---@field combo integer
---@field judged integer
---@field combo_portion number
---@field chart_info {hp: number, multiplier: number, judges: integer, max_combo_portion: number}?
local OsuManiaV2Score = ScoreSystem + IAccuracySource + SimpleJudgesSource + IHealthsSource + IScoreSource

OsuManiaV2Score.accuracy_multiplier = 100
OsuManiaV2Score.accuracy_format = "%0.02f%%"
OsuManiaV2Score.judge_names = {"perfect", "great", "good", "ok", "meh", "miss"}

local weights = {305, 300, 200, 100, 50, 0}
-- Combo score of a judge, a perfect gives 300 here.
local combo_weights = {300, 300, 200, 100, 50, 0}

local default_hp = 5
local log4_400 = math.log(400) / math.log(4)

---@param judge integer 1..5, a miss is not here
---@param hp number
---@param multiplier number
---@return number
local function healthIncrease(judge, hp, multiplier)
	if judge == 5 then
		return -(hp + 1) * 0.0016
	elseif judge == 4 then
		return 0
	elseif judge == 3 then
		return multiplier * (0.004 - hp * 0.0004)
	elseif judge == 2 then
		return multiplier * (0.005 - hp * 0.0005)
	end
	return multiplier * (0.0055 - hp * 0.0005)
end

---osu!'s DifficultyRange
---@param d number
---@param min number
---@param mid number
---@param max number
---@return number
local function range(d, min, mid, max)
	if d > 5 then
		return mid + (max - mid) * (d - 5) / 5
	elseif d < 5 then
		return mid - (mid - min) * (5 - d) / 5
	end
	return mid
end

---Port of LegacyDrainingHealthProcessor.ComputeDrainRate, mania discards the drain and keeps the recovery multiplier.
---shortcut: breaks of the chart are not known here, osu! stops the drain in them; add them when the chart has breaks.
---@param objects {[1]: number, [2]: number, [3]: boolean}[] start and end in milliseconds, is long; sorted by start
---@param hp number
---@return number
local function computeHpMultiplier(objects, hp)
	if #objects == 0 then
		return 1
	end

	local lowest_ever = range(hp, 0.975, 0.8, 0.3)
	local lowest_end = range(hp, 0.99, 0.9, 0.4)
	local recovery_available = range(hp, 0.04, 0.02, 0)

	local multiplier = 1
	local test_drop = 0.00025

	while true do
		local current, uncapped = 1, 1
		local perfect = healthIncrease(1, hp, multiplier)
		local last_time = objects[1][1]
		local fail = false

		for _, o in ipairs(objects) do
			local start, finish, long = o[1], o[2], o[3]

			local drop = test_drop * (start - last_time)
			uncapped = math.max(0, uncapped - drop)
			current = math.max(0, current - drop)
			last_time = finish

			if current <= lowest_ever then
				fail = true
				test_drop = test_drop * 0.96
				break
			end

			local reduction = test_drop * (finish - start)
			local overkill = math.max(0, reduction - current)
			uncapped = math.max(0, uncapped - reduction)
			current = math.max(0, current - reduction)

			-- the head and the tail of a long note, the note itself gives nothing
			local count = long and 2 or 1
			uncapped = uncapped + perfect * count
			current = math.min(1, current + perfect * count)

			if overkill > 0 and current - overkill <= lowest_ever then
				fail = true
				test_drop = test_drop * 0.96
				break
			end
		end

		if not fail and current < lowest_end then
			fail = true
			test_drop = test_drop * 0.94
			multiplier = multiplier * 1.01
		end

		if not fail and (uncapped - 1) / math.max(1, #objects) < recovery_available then
			fail = true
			test_drop = test_drop * 0.96
			multiplier = multiplier * 1.01
		end

		if not fail and multiplier == math.huge then
			return 1
		end

		if not fail then
			return multiplier
		end
	end
end

---@param od number
function OsuManiaV2Score:new(od)
	self.timings = Timings("osuod", od)
	self.subtimings = Subtimings("scorev", 2)

	self.od = od

	self.judge_counter = JudgeCounter(6)
	self.judge_accuracy = JudgeAccuracy(weights)

	local w = OsuManiaV2Timings:getNoteWindows(od)
	local tw = OsuManiaV2Timings:getTailWindows(od)

	self.judge_windows = JudgeWindows({w.perfect, w.great, w.good, w.ok, w.meh, w.miss})
	self.tail_judge_windows = JudgeWindows({tw.perfect, tw.great, tw.good, tw.ok, tw.meh, tw.miss})
	self.slice_input = nil
	self.slice_judge_index = nil

	self.health = 100
	self.combo = 0
	self.judged = 0
	self.combo_portion = 0
end

---@param chart chart.Chart?
function OsuManiaV2Score:setChart(chart)
	ScoreSystem.setChart(self, chart)
	self.chart_info = nil
end

---Chart-dependent constants, found when the first judge comes.
---@return {hp: number, multiplier: number, judges: integer, max_combo_portion: number}
function OsuManiaV2Score:getChartInfo()
	local info = self.chart_info
	if info then
		return info
	end

	local healths = self.chart_healths
	local hp = healths and healths.name == "simple" and healths.data / 10 or default_hp

	---@type {[1]: number, [2]: number, [3]: boolean}[]
	local objects = {}
	local judges = 0
	if self.chart then
		for _, note in ipairs(self.chart.notes:getLinkedNotes()) do
			local t = note:getType()
			if t == "tap" or t == "hold" then
				local long = note:isLong()
				table.insert(objects, {note:getStartTime() * 1000, note:getEndTime() * 1000, long})
				judges = judges + (long and 2 or 1)
			end
		end
		table.sort(objects, function(a, b) return a[1] < b[1] end)
	else
		judges = self.notes_count or 0
	end

	local max_combo_portion = 0 ---@type number
	for c = 1, judges do
		max_combo_portion = max_combo_portion + 300 * math.min(math.max(0.5, math.log(c) / math.log(4)), log4_400)
	end

	info = {
		hp = hp,
		multiplier = computeHpMultiplier(objects, hp),
		judges = judges,
		max_combo_portion = max_combo_portion,
	}
	self.chart_info = info
	return info
end

---@param index integer judge index, negative for a miss
---@param is_part boolean the head or the tail of a long note
function OsuManiaV2Score:judge(index, is_part)
	local info = self:getChartInfo()

	-- a hit in the miss window is a miss
	if index == 6 then
		index = -1
	end

	if not self:isFailed() then
		local delta ---@type number
		if index < 0 then
			delta = -(info.hp + 1) * (is_part and 0.00375 or 0.0075)
		else
			delta = healthIncrease(index, info.hp, info.multiplier)
		end
		self.health = math.min(math.max(self.health + delta * 100, 0), 100)
	end

	if index < 0 then
		self.combo = 0
	else
		self.combo = self.combo + 1
	end
	self.judged = self.judged + 1
	self.combo_portion = self.combo_portion +
		combo_weights[index < 0 and 6 or index] * math.min(math.max(0.5, math.log(self.combo) / math.log(4)), log4_400)
end

---@return number
function OsuManiaV2Score:getHealths()
	return self.health
end

---@return number
function OsuManiaV2Score:getMaxHealths()
	return 100
end

---@return boolean
function OsuManiaV2Score:isFailed()
	return self.health <= 0
end

---@return number
function OsuManiaV2Score:getScore()
	local info = self:getChartInfo()
	local accuracy = self.judged > 0 and self:getAccuracy() or 1
	local combo_progress = info.max_combo_portion > 0 and self.combo_portion / info.max_combo_portion or 1
	local accuracy_progress = info.judges > 0 and self.judged / info.judges or 1
	return math.floor(150000 * combo_progress + 850000 * accuracy ^ (2 + 2 * accuracy) * accuracy_progress + 0.5)
end

---@return string
function OsuManiaV2Score:getKey()
	return "osu_mania_v2_od" .. self.od
end

---@param event rizu.LogicNoteChange
function OsuManiaV2Score:hit(event)
	local is_release = event.new_state == "endPassed" or event.new_state == "endMissedPassed"

	local windows = is_release and self.tail_judge_windows or self.judge_windows
	local index = windows:get(event.delta_time) or -1

	-- lazer caps a tail to meh when the head was missed
	if is_release and event.old_state == "startMissedPressed" and index ~= -1 and index < 5 then
		index = 5
	end

	self.judge_counter:add(index)
	self:judge(index, event.type == "hold")
	self.slice_input = event.column
	self.slice_judge_index = index
end

---@param event rizu.LogicNoteChange
function OsuManiaV2Score:miss(event)
	self.judge_counter:add(-1)
	self:judge(-1, event.type == "hold")
	self.slice_input = event.column
	self.slice_judge_index = -1
end

function OsuManiaV2Score:getAccuracy()
	return self.judge_accuracy:get(self.judge_counter.judges)
end

function OsuManiaV2Score:getSlice()
	local slice = {
		input = self.slice_input,
		judge_index = self.slice_judge_index,
		accuracy = self:getAccuracy(),
		score = self:getScore(),
		healths = self.health,
		max_healths = 100,
		last_judge = self:getLastJudge(),
	}
	self.slice_input = nil
	self.slice_judge_index = nil
	return slice
end

OsuManiaV2Score.events = {
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
			endMissed = "miss",
			endPassed = "hit",
		},
		startMissedPressed = {
			endMissedPassed = "hit",
			startMissed = nil,
			endMissed = nil,
		},
		startMissed = {
			startMissedPressed = nil,
			endMissed = "miss",
		},
	},
}

return OsuManiaV2Score
