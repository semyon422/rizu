-- SOURCE: https://osu.ppy.sh/wiki/en/Gameplay/Judgement/osu!mania

local ScoreSystem = require("rizu.engine.ScoreEngine.ScoreSystem")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local SimpleJudgesSource = require("rizu.engine.ScoreEngine.SimpleJudgesSource")
local JudgeAccuracy = require("rizu.engine.ScoreEngine.JudgeAccuracy")
local JudgeCounter = require("rizu.engine.ScoreEngine.JudgeCounter")
local JudgeWindows = require("rizu.engine.ScoreEngine.JudgeWindows")
local OsuManiaV2Timings = require("sea.timings.osumania.OsuManiaV2Timings_v2")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

---@class rizu.OsuManiaV2Score: rizu.ScoreSystem, rizu.IAccuracySource, rizu.SimpleJudgesSource
---@operator call: rizu.OsuManiaV2Score
local OsuManiaV2Score = ScoreSystem + IAccuracySource + SimpleJudgesSource

OsuManiaV2Score.accuracy_multiplier = 100
OsuManiaV2Score.accuracy_format = "%0.02f%%"
OsuManiaV2Score.judge_names = {"perfect", "great", "good", "ok", "meh", "miss"}

local weights = {305, 300, 200, 100, 50, 0}

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
	self.slice_input = event.column
	self.slice_judge_index = index
end

---@param event rizu.LogicNoteChange
function OsuManiaV2Score:miss(event)
	self.judge_counter:add(-1)
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
