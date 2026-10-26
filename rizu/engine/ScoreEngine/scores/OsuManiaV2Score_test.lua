local OsuManiaV2Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV2Score")
local Healths = require("sea.chart.Healths")

local test = {}

---@param new_state rizu.TapLogicNoteState
---@param delta_time number?
---@return rizu.LogicNoteChange
local function tap_event(new_state, delta_time)
	return {
		index = 1,
		type = "tap",
		time = 0,
		delta_time = delta_time or 0,
		old_state = "clear",
		new_state = new_state,
	}
end

---@param n integer
---@param long boolean?
---@return chart.Chart
local function fake_chart(n, long)
	local notes = {}
	for i = 1, n do
		local start = i * 0.25
		notes[i] = {
			getType = function() return long and "hold" or "tap" end,
			isLong = function() return not not long end,
			getStartTime = function() return start end,
			getEndTime = function() return long and start + 0.1 or start end,
		}
	end
	return {notes = {getLinkedNotes = function() return notes end}} --[[@as chart.Chart]]
end

---@param t testing.T
function test.perfect_play_is_a_million(t)
	local score = OsuManiaV2Score(8)
	score:load({notes_count = 0, chart = fake_chart(100)})
	for _ = 1, 100 do
		score:receive(tap_event("passed", 0.001))
	end
	t:eq(score:getScore(), 1000000)
	t:eq(score:getHealths(), 100)
end

---@param t testing.T
function test.great_everywhere_loses_accuracy_not_combo(t)
	local score = OsuManiaV2Score(8)
	score:load({notes_count = 0, chart = fake_chart(100)})
	for _ = 1, 100 do
		score:receive(tap_event("passed", 0.03)) -- great at OD8: 40ms, perfect 16ms
	end
	local acc = 300 / 305
	t:eq(score:getScore(), math.floor(150000 + 850000 * acc ^ (2 + 2 * acc) + 0.5))
end

---@param t testing.T
function test.miss_breaks_combo_and_drains(t)
	local score = OsuManiaV2Score(8)
	score:load({notes_count = 0, healths = Healths("simple", 50), chart = fake_chart(100)})
	score:receive(tap_event("passed", 0.001))
	local before = score:getHealths()
	score:receive(tap_event("missed"))
	-- (HP + 1) * 0.0075
	t:eq(before - score:getHealths(), 6 * 0.75)
	t:eq(score.combo, 0)
end

---@param t testing.T
function test.fails_at_zero_and_stays_failed(t)
	local score = OsuManiaV2Score(8)
	score:load({notes_count = 0, healths = Healths("simple", 100), chart = fake_chart(200)})
	for _ = 1, 200 do
		score:receive(tap_event("missed"))
	end
	t:assert(score:isFailed())
	t:eq(score:getHealths(), 0)
	score:receive(tap_event("passed", 0.001))
	t:eq(score:getHealths(), 0)
end

---@param old_state rizu.HoldLogicNoteState
---@param new_state rizu.HoldLogicNoteState
---@param delta_time number?
---@return rizu.LogicNoteChange
local function hold_event(old_state, new_state, delta_time)
	return {
		index = 1,
		type = "hold",
		time = 0,
		delta_time = delta_time or 0,
		old_state = old_state,
		new_state = new_state,
	}
end

---@param t testing.T
function test.hold_break_breaks_combo_and_judges_only_the_tail(t)
	local score = OsuManiaV2Score(8)
	score:load({notes_count = 0, chart = fake_chart(1, true)})
	score:receive(hold_event("clear", "startPassedPressed", 0.001))
	t:eq(score.combo, 1)
	local health = score:getHealths()

	score:receive(hold_event("startPassedPressed", "startMissed", -1))
	t:eq(score.combo, 0)
	t:eq(score.judged, 1)
	t:eq(score.judge_counter.total, 1)
	t:eq(score:getHealths(), health)

	score:receive(hold_event("startMissed", "startMissedPressed", -1))
	score:receive(hold_event("startMissedPressed", "endMissedPassed", 0.001))
	t:eq(score.judged, 2)
	t:eq(score.judge_counter.judges[5], 1) -- the tail is capped at meh
end

---@param t testing.T
function test.late_head_with_a_missed_release_has_two_misses(t)
	local score = OsuManiaV2Score(8)
	score:load({notes_count = 0, chart = fake_chart(1, true)})
	score:receive(hold_event("clear", "startMissedPressed", 0.15))
	score:receive(hold_event("startMissedPressed", "endMissed", -0.5))
	t:eq(score.judge_counter.judges[6], 2)
	t:eq(score.judged, score.judges)
end

---@param t testing.T
function test.head_missed_tail_is_capped_at_meh(t)
	local score = OsuManiaV2Score(8)
	score:receive({
		index = 1, type = "hold", time = 0, delta_time = 0.001,
		old_state = "startMissedPressed", new_state = "endMissedPassed",
	})
	t:eq(score.judge_counter.judges[5], 1)
end

return test
