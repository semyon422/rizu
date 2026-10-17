local LunaticRaveScore = require("rizu.engine.ScoreEngine.scores.LunaticRaveScore")

local test = {}

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
function test.score_uses_lr2_weights(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(5)

	score.judge_counter:add(1) -- PGREAT: 4
	score.judge_counter:add(2) -- GREAT: 2
	score.judge_counter:add(3) -- GOOD: 1
	score.judge_counter:add(4) -- BAD: 0
	score.judge_counter:add(5) -- POOR: 0

	t:eq(score:getScore(), 70000)
	t:eq(score:getSlice().score, 70000)
	t:eq(score:getExScore(), 3)
	t:eq(score:getSlice().ex_score, 3)
end

---@param t testing.T
function test.score_maximum_is_200000(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(2)

	score.judge_counter:add(1)
	score.judge_counter:add(1)

	t:eq(score:getScore(), 200000)
end

---@param t testing.T
function test.score_is_zero_without_notes(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(0)

	t:eq(score:getScore(), 0)
end

---@param t testing.T
function test.long_note_is_judged_at_release(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:receive(hold_event("clear", "startPassedPressed", 0))
	t:eq(score.judge_counter.total, 0)
	t:eq(score:getLastJudge(), nil)

	score:receive(hold_event("startPassedPressed", "endPassed", 0))
	t:eq(score.judge_counter.total, 1)
	t:eq(score.judge_counter:get(1), 1)
	t:eq(score:getScore(), 200000)
end

---@param t testing.T
function test.long_note_early_release_is_bad(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:receive(hold_event("clear", "startPassedPressed", 0))
	score:receive(hold_event("startPassedPressed", "startMissed", -0.101))

	t:eq(score.judge_counter.total, 1)
	t:eq(score.judge_counter:get(4), 1)
end

---@param t testing.T
function test.long_note_release_inside_good_window_keeps_head_judge(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:receive(hold_event("clear", "startPassedPressed", 0.03))
	score:receive(hold_event("startPassedPressed", "endPassed", -0.1))

	t:eq(score.judge_counter:get(2), 1)
end

---@param t testing.T
function test.long_note_held_past_tail_keeps_head_judge(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:receive(hold_event("clear", "startPassedPressed", 0.07))
	score:receive(hold_event("startPassedPressed", "endMissed", 0.2))

	t:eq(score.judge_counter.total, 1)
	t:eq(score.judge_counter:get(3), 1)
end

---@param t testing.T
function test.long_note_early_release_is_not_counted_twice(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:receive(hold_event("clear", "startPassedPressed", 0))
	score:receive(hold_event("startPassedPressed", "startMissed", -0.2))
	score:receive(hold_event("startMissed", "endMissed", 0.2))

	t:eq(score.judge_counter.total, 1)
	t:eq(score.judge_counter:get(4), 1)
end

---@param t testing.T
function test.combo_increments_for_good_or_better(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(3)

	score:hit({delta_time = 0})
	score:hit({delta_time = 0.03})
	score:hit({delta_time = 0.07})

	t:eq(score:getCombo(), 3)
	t:eq(score:getMaxCombo(), 3)
	t:eq(score:getSlice().combo, 3)
end

---@param t testing.T
function test.bad_and_poor_break_combo(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(4)

	score:hit({delta_time = 0})
	score:hit({delta_time = 0.15})
	t:eq(score:getCombo(), 0)
	t:eq(score:getMaxCombo(), 1)

	score:hit({delta_time = 0})
	score:miss({index = 1})
	t:eq(score:getCombo(), 0)
	t:eq(score:getMaxCombo(), 1)
end

---@param t testing.T
function test.mash_does_not_break_combo_or_consume_note(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:hit({delta_time = 0})
	score:mash({delta_time = -0.5})

	t:eq(score:getCombo(), 1)
	t:eq(score:getMaxCombo(), 1)
	t:eq(score.judge_counter.total, 1)
	t:eq(score.judge_counter:get(5), 1)
	t:eq(score:getAccuracy(), 1)
end

---@param t testing.T
function test.mash_outside_early_poor_window_is_ignored(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:mash({delta_time = -1})
	score:mash({delta_time = -2})

	t:eq(score.judge_counter.total, 0)
	t:eq(score.judge_counter:get(5), 0)
end

---@param t testing.T
function test.rank_4_uses_normal_windows(t)
	local score = LunaticRaveScore(4)
	score:setNotesCount(2)

	score:hit({delta_time = 0.019})
	score:hit({delta_time = 0.101})

	t:eq(score.judge_counter:get(2), 1)
	t:eq(score.judge_counter:get(4), 1)
end

---@param t testing.T
function test.long_note_combo_changes_at_release(t)
	local score = LunaticRaveScore(2)
	score:setNotesCount(1)

	score:receive(hold_event("clear", "startPassedPressed", 0))
	t:eq(score:getCombo(), 0)

	score:receive(hold_event("startPassedPressed", "endPassed", 0))
	t:eq(score:getCombo(), 1)
	t:eq(score:getMaxCombo(), 1)
end

return test
