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
	score:setChart(fake_chart(100))
	for _ = 1, 100 do
		score:receive(tap_event("passed", 0.001))
	end
	t:eq(score:getScore(), 1000000)
	t:eq(score:getHealths(), 100)
end

---@param t testing.T
function test.great_everywhere_loses_accuracy_not_combo(t)
	local score = OsuManiaV2Score(8)
	score:setChart(fake_chart(100))
	for _ = 1, 100 do
		score:receive(tap_event("passed", 0.03)) -- great at OD8: 40ms, perfect 16ms
	end
	local acc = 300 / 305
	t:eq(score:getScore(), math.floor(150000 + 850000 * acc ^ (2 + 2 * acc) + 0.5))
end

---@param t testing.T
function test.miss_breaks_combo_and_drains(t)
	local score = OsuManiaV2Score(8)
	score:setChart(fake_chart(100))
	score:setChartHealths(Healths("simple", 50))
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
	score:setChart(fake_chart(200))
	score:setChartHealths(Healths("simple", 100))
	for _ = 1, 200 do
		score:receive(tap_event("missed"))
	end
	t:assert(score:isFailed())
	t:eq(score:getHealths(), 0)
	score:receive(tap_event("passed", 0.001))
	t:eq(score:getHealths(), 0)
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
