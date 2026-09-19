local OsuManiaV1Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV1Score")

local test = {}

---@param t testing.T
function test.long_note_is_judged_once(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)
	local event = {index = 1}

	score:addCounter(1)
	score:before(event)
	score:longNoteStartHit({index = event.index, delta_time = 0})
	t:eq(score.judge_counter.total, 1)
	t:eq(score:getLastJudge(), nil)
	t:eq(score:getSlice().visual_judge, 1)

	score:longNoteRelease({index = event.index, delta_time = 0})
	t:eq(score.judge_counter.total, 2)
	t:eq(score.judge_counter:get(1), 2)
	t:eq(score:getLastJudge(), 1)
	t:eq(score:getSlice().visual_judge, 1)
end

---@param t testing.T
function test.long_note_uses_combined_head_and_tail_error(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)
	local event = {index = 1}

	-- At OD 8, ±20ms is a 300g head, but ±20ms at both ends exceeds
	-- its 38.4ms combined-error limit and is therefore a 300.
	score:longNoteStartHit({index = event.index, delta_time = 0.020})
	score:longNoteRelease({index = event.index, delta_time = -0.020})

	t:eq(score.judge_counter:get(2), 1)
end

---@param t testing.T
function test.long_note_hold_break_caps_300_at_200(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)
	local event = {index = 1}

	score:longNoteStartHit({index = event.index, delta_time = 0})
	score:longNoteFail(event)
	score:longNoteRelease({index = event.index, delta_time = 0})

	t:eq(score.judge_counter:get(3), 1)
end

---@param t testing.T
function test.long_note_early_tail_outside_50_window_misses(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)

	score:longNoteStartHit({index = 1, delta_time = 0})
	score:didntReleased({index = 1, delta_time = -0.128})

	t:eq(score.judge_counter:get(6), 1)
end

---@param t testing.T
function test.long_note_late_head_uses_recorded_press_time(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)

	-- A 100ms-late press with an exact tail is a stable 100, not an automatic 50.
	score:longNoteFail({index = 1, press_delta_time = 0.100})
	score:longNoteRelease({index = 1, delta_time = 0})

	t:eq(score.judge_counter:get(4), 1)
end

---@param t testing.T
function test.long_note_repress_uses_latest_press_time(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)

	score:longNoteStartHit({index = 1, delta_time = 0})
	score:longNoteFail({index = 1, press_delta_time = 0.100})
	score:longNoteRelease({index = 1, delta_time = 0})

	-- The re-press would be a 100, and a break cannot improve it.
	t:eq(score.judge_counter:get(4), 1)
end

---@param t testing.T
function test.score_uses_stable_miss_penalty(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(2)

	score:addCounter(1)
	score:addCounter(6)

	t:eq(score.bonus, 44)
	t:eq(score:getScore(), 500000)
end

---@param t testing.T
function test.score_truncates_each_event(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(3)

	score:addCounter(2)
	t:eq(score:getScore(), math.floor(score:getScore()))
end

return test
