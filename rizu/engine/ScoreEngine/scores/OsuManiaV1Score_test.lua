local OsuManiaV1Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV1Score")
local Healths = require("sea.chart.Healths")

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
function test.slice_reports_long_note_head_feedback(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(1)

	score:longNoteStartHit({index = 1, column = 2, delta_time = 0})
	local slice = score:getSlice()
	t:eq(slice.input, 2)
	t:eq(slice.judge_index, 1)
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

	t:eq(score.bonus, 0)
	t:eq(score:getScore(), 500000)
end

---@param t testing.T
function test.hold_break_resets_combo(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(2)

	score:longNoteStartHit({index = 1, delta_time = 0})
	score:addCounter(1)
	t:eq(score.combo, 1)
	score:longNoteFail({index = 1})
	t:eq(score.combo, 0)
end

---@param t testing.T
function test.score_truncates_each_event(t)
	local score = OsuManiaV1Score(8)
	score:setNotesCount(3)

	score:addCounter(2)
	t:eq(score:getScore(), math.floor(score:getScore()))
end

---@param n integer
---@return chart.Chart
local function fake_chart(n)
	local notes = {}
	for i = 1, n do
		notes[i] = {
			getType = function() return "tap" end,
			getStartTime = function() return i * 0.25 end,
			getEndTime = function() return i * 0.25 end,
		}
	end
	return {notes = {getLinkedNotes = function() return notes end}} --[[@as chart.Chart]]
end

---@param t testing.T
function test.hp_follows_stable_judgement_values(t)
	local score = OsuManiaV1Score(8)
	score:setChartHealths(Healths("simple", 50))
	score:setNotesCount(10)
	t:eq(score:getHealths(), 100)

	score:addCounter(6)
	-- (HP + 1) * 1.5 of 200
	t:eq(score:getHealths(), 100 - 6 * 1.5 / 2)

	local before = score:getHealths()
	score:addCounter(4)
	t:eq(score:getHealths(), before)
	score:addCounter(5)
	t:eq(score:getHealths(), before - 6 * 0.32 / 2)
end

---@param t testing.T
function test.hp_multiplier_makes_a_perfect_play_recover(t)
	local score = OsuManiaV1Score(8)
	score:setChart(fake_chart(100))
	score:setChartHealths(Healths("simple", 80))
	score:setNotesCount(100)
	local info = score:getHpInfo()
	t:assert(info.multiplier >= 1)
	score:addCounter(6)
	score:addCounter(1)
	t:assert(score:getHealths() > 0)
end

---@param t testing.T
function test.hp_fails_at_zero_and_stays_failed(t)
	local score = OsuManiaV1Score(8)
	score:setChartHealths(Healths("simple", 100))
	score:setNotesCount(200)
	for _ = 1, 200 do
		score:addCounter(6)
	end
	t:assert(score:isFailed())
	t:eq(score:getHealths(), 0)
	score:addCounter(1)
	t:eq(score:getHealths(), 0)
end

return test
