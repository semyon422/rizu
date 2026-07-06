local class = require("class")

---@class rizu.JudgesSlice
---@field last_judge integer

---@class rizu.IJudgesSource
---@operator call: rizu.IJudgesSource
local IJudgesSource = class()

---@return integer[]
function IJudgesSource:getJudges()
	error("not implemented")
end

---@return string[]
function IJudgesSource:getJudgeNames()
	error("not implemented")
end

---@return integer
function IJudgesSource:getJudgesTotal()
	error("not implemented")
end

---@return integer?
function IJudgesSource:getLastJudge()
	error("not implemented")
end

---@return integer
function IJudgesSource:getNotPerfect()
	error("not implemented")
end

---@return rizu.JudgesSlice
function IJudgesSource:getSlice()
	return {
		last_judge = self:getLastJudge(),
	}
end

return IJudgesSource
