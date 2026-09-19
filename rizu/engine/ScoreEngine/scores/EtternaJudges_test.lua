local EtternaJudges = require("rizu.engine.ScoreEngine.scores.EtternaJudges")

local test = {}

---@param old_state rizu.HoldLogicNoteState
---@param new_state rizu.HoldLogicNoteState
---@return rizu.LogicNoteChange
local function hold_event(old_state, new_state)
	return {
		index = 1,
		type = "hold",
		time = 0,
		delta_time = 0,
		old_state = old_state,
		new_state = new_state,
	}
end

---@param t testing.T
function test.counts_completed_and_dropped_holds_separately(t)
	local score = EtternaJudges(4)

	score:receive(hold_event("clear", "startPassedPressed"))
	score:receive(hold_event("startPassedPressed", "endPassed"))
	score:receive(hold_event("clear", "startPassedPressed"))
	score:receive(hold_event("startPassedPressed", "endMissed"))

	t:eq(score.holds_held, 1)
	t:eq(score.holds_let_go, 1)
	t:eq(score.holds_missed, 0)
	t:eq(score.judge_counter.total, 2)
end

return test
