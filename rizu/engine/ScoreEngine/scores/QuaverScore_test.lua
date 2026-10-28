local QuaverScore = require("rizu.engine.ScoreEngine.scores.QuaverScore")

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

---@param t testing.T
function test.health_follows_base_weights_from_12_actions_per_second(t)
	local score = QuaverScore()
	local info = {notes_count = 0, density = 12}
	score:load(info)
	score:loadChart(info)
	t:eq(score:getHealths(), 100)

	score:receive(tap_event("missed"))
	t:eq(score:getHealths(), 94)
	score:receive(tap_event("passed", 0.01)) -- marvelous
	t:eq(score:getHealths(), 94.5)
	t:assert(not score:isFailed())
end

---@param t testing.T
function test.density_scales_weights_and_floors_at_2(t)
	local score = QuaverScore()
	local info = {notes_count = 0, density = 1}
	score:load(info)
	score:loadChart(info)
	local floor = score.health_weights
	local info = {notes_count = 0, density = 2}
	score:load(info)
	score:loadChart(info)
	t:eq(floor[1], score.health_weights[1])
	-- marvelous: (-0.14 * 2 + 2.68) * 0.5 = 1.2
	t:eq(score.health_weights[1], 1.2)
	-- miss is not scaled
	t:eq(score.health_weights[6], -6)
end

---@param t testing.T
function test.fails_at_zero_and_stays_failed(t)
	local score = QuaverScore()
	for _ = 1, 17 do
		score:receive(tap_event("missed"))
	end
	t:assert(score:isFailed())
	t:eq(score:getHealths(), 0)

	score:receive(tap_event("passed", 0.01))
	t:eq(score:getHealths(), 0)
	t:assert(score:isFailed())
end

---@param t testing.T
function test.health_stays_at_most_100(t)
	local score = QuaverScore()
	local info = {notes_count = 0, density = 12}
	score:load(info)
	score:loadChart(info)
	score:receive(tap_event("passed", 0.01))
	t:eq(score:getHealths(), 100)
end

---@param t testing.T
function test.missed_long_note_head_is_two_misses_and_accuracy_not_negative(t)
	local score = QuaverScore()
	local event = {index = 1, type = "hold", time = 0, delta_time = 0, old_state = "clear", new_state = "startMissed"}
	score:receive(event)
	t:eq(score.judge_counter.judges[6], 2)
	event.old_state, event.new_state = "startMissed", "endMissed"
	score:receive(event)
	t:eq(score.judge_counter.judges[6], 2)
	t:eq(score:getAccuracy(), 0)
end

---@param t testing.T
function test.late_release_in_okay_window_is_good(t)
	local score = QuaverScore()
	score:receive({index = 1, column = "key1", type = "hold", time = 0, delta_time = 0.01, old_state = "clear", new_state = "startPassedPressed"})
	score:receive({index = 1, column = "key1", type = "hold", time = 0, delta_time = 0.12 * 1.5, old_state = "startPassedPressed", new_state = "endPassed"})
	t:eq(score.judge_counter.judges[5], 0)
	t:eq(score.judge_counter.judges[4], 1)
end

return test
