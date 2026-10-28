local SoundsphereScore = require("rizu.engine.ScoreEngine.scores.SoundsphereScore")

local test = {}

---@param t testing.T
function test.hit_counts_judge_accuracy_and_healths(t)
	local score = SoundsphereScore()
	score:load({notes_count = 1})
	score:receive({type = "tap", old_state = "clear", new_state = "passed", delta_time = 0.01, column = "key1"} --[[@as any]])
	t:eq(score:getJudges()[1], 1)
	t:eq(score:getHealths(), 501)
	t:aeq(score:getSlice().mean, 0.01, 1e-9)
	t:eq(score.judge_counter.last, 1)
end

---@param t testing.T
function test.missed_hold_start_takes_healths_without_a_judge(t)
	local score = SoundsphereScore()
	score:load({notes_count = 1})
	score:receive({type = "hold", old_state = "clear", new_state = "startMissed", delta_time = 0.2, column = "key1"} --[[@as any]])
	t:eq(score:getJudgesTotal(), 0)
	t:eq(score:getHealths(), 450)
	score:receive({type = "hold", old_state = "startMissed", new_state = "endMissed", delta_time = 0.2, column = "key1"} --[[@as any]])
	t:eq(score:getJudges()[3], 1)
	t:eq(score:getHealths(), 400)
end

return test
