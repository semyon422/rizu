local class = require("class")

---@class rizu.TimeSkip
---@operator call: rizu.TimeSkip
local TimeSkip = class()

---@param chart chart.Chart
---@param time_to_prepare number
---@param rate number
function TimeSkip:new(chart, time_to_prepare, rate)
	self.chart = chart
	self.time_to_prepare = time_to_prepare
	self.rate = rate
end

---@param time number
function TimeSkip:setTime(time)
	self.time = time
end

function TimeSkip:getStartTime()
	return 0
end

---@return boolean
function TimeSkip:canSkip()
	return self.time < 0
end

---@return number
function TimeSkip:skip()
	return 0
end

return TimeSkip
