local class = require("class")

--- Monotonic time adjust
---@class rizu.TimeAdjust
---@operator call: rizu.TimeAdjust
local TimeAdjust = class()

---@param adjust_factor number?
function TimeAdjust:new(adjust_factor)
	self:setFactor(adjust_factor or 1)
end

---@param adjust_factor number from 0 to 1
function TimeAdjust:setFactor(adjust_factor)
	assert(adjust_factor >= 0 and adjust_factor <= 1)
	self.adjust_factor = adjust_factor
end

---@param time number
---@param adjust_time number
---@return number?
function TimeAdjust:adjust(time, adjust_time)
	if adjust_time == self.adjust_time then
		return
	end
	self.adjust_time = adjust_time

	return time + (adjust_time - time) * self.adjust_factor
end

return TimeAdjust
