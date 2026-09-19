local EtternaAccuracy = require("rizu.engine.ScoreEngine.scores.EtternaAccuracy")

local test = {}

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
function test.completed_hold_has_no_tail_wife_score(t)
	local score = EtternaAccuracy(4)

	score:receive(hold_event("clear", "startPassedPressed"))
	score:receive(hold_event("startPassedPressed", "endPassed"))

	t:eq(score.points, 2)
	t:eq(score.notes, 1)
	t:eq(score.holds_held, 1)
	t:eq(score.holds_let_go, 0)
	t:eq(score.holds_missed, 0)
end

---@param t testing.T
function test.dropped_hold_adds_fixed_wife3_penalty(t)
	local score = EtternaAccuracy(4)

	score:receive(hold_event("clear", "startPassedPressed"))
	score:receive(hold_event("startPassedPressed", "endMissed"))

	t:eq(score.points, -2.5) -- 2 for the head, -4.5 for the dropped hold
	t:eq(score.notes, 1)
	t:eq(score.holds_held, 0)
	t:eq(score.holds_let_go, 1)
	t:eq(score.holds_missed, 0)
end

---@param t testing.T
function test.missed_head_hold_adds_miss_and_hold_penalty(t)
	local score = EtternaAccuracy(4)

	score:receive(hold_event("clear", "startMissed"))
	score:receive(hold_event("startMissed", "endMissed"))

	t:eq(score.points, -10) -- -5.5 head miss, -4.5 missed hold
	t:eq(score.notes, 1)
	t:eq(score.holds_held, 0)
	t:eq(score.holds_let_go, 0)
	t:eq(score.holds_missed, 1)
end

---@param t testing.T
function test.late_pressed_missed_hold_adds_hold_penalty(t)
	local score = EtternaAccuracy(4)

	score:receive(hold_event("clear", "startMissed"))
	score:receive(hold_event("startMissed", "startMissedPressed"))
	score:receive(hold_event("startMissedPressed", "endMissedPassed"))

	t:eq(score.points, -10)
	t:eq(score.notes, 1)
	t:eq(score.holds_held, 0)
	t:eq(score.holds_let_go, 0)
	t:eq(score.holds_missed, 1)
end

return test
