local class = require("class")

---@class rizu.JudgeCounter
---@operator call: rizu.JudgeCounter
---@field judges {[integer]: integer}
local JudgeCounter = class()

---@param size integer
function JudgeCounter:new(size)
	self.size = size
	self.total = 0
	self.judges = {}
	for i = 1, size do
		self.judges[i] = 0
	end
end

---@param index integer
---@param not_total boolean?
function JudgeCounter:add(index, not_total)
	if index < 0 then
		index = self.size + index + 1
	end
	if not not_total then
		self.total = self.total + 1
	end
	self.judges[index] = self.judges[index] + 1
	self.last = index
end

---@param index integer
---@return integer
function JudgeCounter:get(index)
	if index < 0 then
		index = self.size + index + 1
	end
	return assert(self.judges[index])
end

---@return integer
function JudgeCounter:getNotPerfect()
	local judges = self.judges
	local sum = 0
	for i = 2, self.size do
		sum = sum + judges[i]
	end
	return sum
end

return JudgeCounter
