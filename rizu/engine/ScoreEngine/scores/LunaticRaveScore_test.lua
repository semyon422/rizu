local LunaticRaveScore = require("rizu.engine.ScoreEngine.scores.LunaticRaveScore")
local Healths = require("sea.chart.Healths")

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

---@param gauge integer?
---@param total integer? Without it the chart has no #TOTAL.
---@return rizu.LunaticRaveScore
local function gauge_score(gauge, total)
	local score = LunaticRaveScore(2, gauge)
	score:setNotesCount(100)
	score:setChartHealths(total and Healths("bmstotal", total) or nil)
	return score
end

---@param a number
---@param b number
---@return boolean
local function near(a, b)
	return math.abs(a - b) < 1e-9
end

---@param t testing.T
function test.groove_and_easy_gain_total_per_note(t)
	local groove = gauge_score(0, 300)
	t:eq(groove:getHealths(), 20)
	groove:changeHealth(1)
	groove:changeHealth(3)
	t:assert(near(groove:getHealths(), 20 + 3 + 1.5))
	groove:changeHealth(4)
	groove:changeHealth(6)
	t:assert(near(groove:getHealths(), 20 + 4.5 - 4 - 2))

	local easy = gauge_score(1, 300)
	easy:changeHealth(2)
	easy:changeHealth(5)
	t:assert(near(easy:getHealths(), 20 + 1.2 * 3 - 0.8 * 6))
end

---@param t testing.T
function test.groove_stays_alive_and_clears_at_80(t)
	local groove = gauge_score(0, 300)
	for _ = 1, 10 do
		groove:changeHealth(5)
	end
	t:eq(groove:getHealths(), 2)
	t:assert(groove:isFailed())

	local rich = gauge_score(0, 300)
	for _ = 1, 20 do
		rich:changeHealth(1)
	end
	t:assert(near(rich:getHealths(), 80))
	t:assert(not rich:isFailed())
end

---@param t testing.T
function test.hard_fails_below_two_and_hurts_less_at_low_gauge(t)
	local hard = gauge_score(2, 300)
	hard:setNotesCount(1000) -- no damage scaling from here
	t:eq(hard:getHealths(), 100)
	hard:changeHealth(5)
	t:assert(near(hard:getHealths(), 90))
	hard:changeHealth(1)
	t:assert(near(hard:getHealths(), 90.1))

	local low = gauge_score(2, 300)
	low:setNotesCount(1000)
	for _ = 1, 7 do
		low:changeHealth(5) -- 100 -> 30
	end
	t:eq(low:getHealths(), 30)
	low:changeHealth(5) -- 0.6 * -10
	t:assert(near(low:getHealths(), 24))
	t:assert(not low:isFailed())
	for _ = 1, 10 do
		low:changeHealth(5)
	end
	t:assert(low:isFailed())

	local hazard = gauge_score(3)
	hazard:changeHealth(6)
	hazard:changeHealth(1)
	t:assert(not hazard:isFailed())
	hazard:changeHealth(4)
	t:assert(hazard:isFailed())
end

---@param t testing.T
function test.hard_damage_grows_for_few_notes_or_low_total(t)
	---@param notes integer
	---@param total integer
	---@return number
	local function poor_damage(notes, total)
		local score = LunaticRaveScore(2, 2)
		score:setNotesCount(notes)
		score:setChartHealths(Healths("bmstotal", total))
		score:changeHealth(5)
		return 100 - score:getHealths()
	end
	t:assert(near(poor_damage(1000, 300), 10)) -- no scaling
	t:assert(near(poor_damage(10, 300), 100)) -- 10x
	t:assert(near(poor_damage(100, 300), 10 * (5 - 40 / 65)))
	t:assert(near(poor_damage(1000, 100), 10 * 10 / 1)) -- (100 - 80) / 16 = 1 step
	t:assert(near(poor_damage(1000, 240), 10 * 10 / 10)) -- 10 steps
end

---@param t testing.T
function test.chart_without_total_gets_the_default(t)
	local groove = gauge_score(0)
	groove:changeHealth(1)
	t:assert(near(groove:getHealths(), 20 + (160 + 100 * 0.16) / 100)) -- 100 notes
end

return test
