local IidxScore = require("rizu.engine.ScoreEngine.scores.IidxScore")

local test = {}

---@param delta_time number
---@return rizu.LogicNoteChange
local function tap_event(delta_time)
	return {
		index = 1,
		type = "tap",
		time = 0,
		delta_time = delta_time,
		old_state = "clear",
		new_state = "passed",
	}
end

---@param t testing.T
function test.normal_note_windows_are_inclusive(t)
	local score = IidxScore()

	score:receive(tap_event(0.01667))
	score:receive(tap_event(-0.03333))
	score:receive(tap_event(0.11667))
	score:receive(tap_event(-0.25000))

	t:eq(score.judge_counter:get(1), 1)
	t:eq(score.judge_counter:get(2), 1)
	t:eq(score.judge_counter:get(3), 1)
	t:eq(score.judge_counter:get(4), 1)
end

---@param t testing.T
function test.outside_bad_window_is_poor(t)
	local score = IidxScore()
	score:hit({delta_time = 0.25000 + 1e-6})
	t:eq(score.judge_counter:get(5), 1)
end

---@param old_state rizu.HoldLogicNoteState
---@param new_state rizu.HoldLogicNoteState
---@param delta_time number
---@return rizu.LogicNoteChange
local function hold_event(old_state, new_state, delta_time)
	return {
		index = 1,
		type = "hold",
		time = 0,
		delta_time = delta_time,
		old_state = old_state,
		new_state = new_state,
	}
end

---@param t testing.T
function test.charge_note_tail_has_special_judgments(t)
	local score = IidxScore()

	score:receive(hold_event("clear", "startPassedPressed", 0))
	score:receive(hold_event("startPassedPressed", "endPassed", 0.11667))
	t:eq(score.judge_counter:get(1), 2)

	score:receive(hold_event("clear", "startPassedPressed", 0))
	score:receive(hold_event("startPassedPressed", "startMissed", -0.11668))
	t:eq(score.judge_counter:get(5), 1)

	score:receive(hold_event("clear", "startPassedPressed", 0))
	score:receive(hold_event("startPassedPressed", "endMissed", 0.11668))
	t:eq(score.judge_counter:get(4), 1)
	t:eq(score.judge_counter.total, 6)
end

---@param t testing.T
function test.bad_charge_note_head_deactivates_tail(t)
	local score = IidxScore()

	score:receive(hold_event("clear", "startPassedPressed", 0.2))
	score:receive(hold_event("startPassedPressed", "endPassed", 0))

	t:eq(score.judge_counter:get(4), 1)
	t:eq(score.judge_counter.total, 1)
end

---@param t testing.T
function test.ex_score_accuracy_and_combo(t)
	local score = IidxScore()

	score:hit({delta_time = 0})
	score:hit({delta_time = 0.02})
	score:hit({delta_time = 0.1})
	t:eq(score:getScore(), 3)
	t:eq(score:getAccuracy(), 0.5)
	t:eq(score:getCombo(), 3)

	score:hit({delta_time = 0.2})
	t:eq(score:getCombo(), 0)
	t:eq(score:getMaxCombo(), 3)
end

return test
