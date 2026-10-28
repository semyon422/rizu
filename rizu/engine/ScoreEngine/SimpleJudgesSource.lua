local IJudgesSource = require("rizu.engine.ScoreEngine.IJudgesSource")

---@class rizu.SimpleJudgesSource: rizu.IJudgesSource
---@operator call: rizu.SimpleJudgesSource
---@field judge_counter rizu.JudgeCounter
---@field judge_names string[]
---@field slice_input chart.Column?
---@field slice_judge_index integer?
local SimpleJudgesSource = IJudgesSource + {}

---@return integer[]
function SimpleJudgesSource:getJudges()
	return self.judge_counter.judges
end

---@return string[]
function SimpleJudgesSource:getJudgeNames()
	return self.judge_names
end

---@return integer
function SimpleJudgesSource:getJudgesTotal()
	return self.judge_counter.total
end

---@return integer?
function SimpleJudgesSource:getLastJudge()
	return self.judge_counter.last
end

---@return integer
function SimpleJudgesSource:getNotPerfect()
	return self.judge_counter:getNotPerfect()
end

---Reports the judge of this event in the next slice.
---@param event rizu.LogicNoteChange
---@param index integer Negative for a miss.
function SimpleJudgesSource:setSliceJudge(event, index)
	self.slice_input = event.column
	self.slice_judge_index = index
end

---The input and judge of the last event for a slice, cleared for the next one.
---@return chart.Column?
---@return integer?
function SimpleJudgesSource:takeSliceJudge()
	local input, index = self.slice_input, self.slice_judge_index
	self.slice_input = nil
	self.slice_judge_index = nil
	return input, index
end

return SimpleJudgesSource
