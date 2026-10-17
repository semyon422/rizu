local Point = require("chart.model.tp.Point")

---@class chart.IntervalPoint: chart.Point
---@operator call: chart.IntervalPoint
---@field _measure chart.Measure?
---@field measure chart.Measure?
---@field _vertex chart.Vertex?
---@field vertex chart.Vertex
local IntervalPoint = Point + {}

---@param time chart.Fraction
function IntervalPoint:new(time)
	self.time = time
end

---@return number
function IntervalPoint:tonumber()
	local id = self.vertex
	if not id then
		return 0
	end
	if id:isSingle() then
		return id.offset
	end
	local a, b, offset = id:getPair()
	local ta = a.offset
	local time = self.time:tonumber() - a:time():tonumber()
	return ta + a:getBeatDuration() * time
end

---@return number
function IntervalPoint:getBeatModulo()
	local measure = self.measure
	if not measure then
		return self.time % 1
	end
	return (self.time + measure.offset) % 1
end

---@return number
function IntervalPoint:getBeatDuration()
	local id = self.vertex
	if not id then
		return 0
	end
	return id:getBeatDuration()
end

---@param a chart.IntervalPoint
---@return string
function IntervalPoint.__tostring(a)
	return ("IntervalPoint(%s)"):format(a.time)
end

---@param a chart.IntervalPoint
---@param b chart.IntervalPoint
---@return boolean
function IntervalPoint.__eq(a, b)
	return a.time == b.time
end

---@param a chart.IntervalPoint
---@param b chart.IntervalPoint
---@return boolean
function IntervalPoint.__lt(a, b)
	return a.time < b.time
end

---@param a chart.IntervalPoint
---@param b chart.IntervalPoint
---@return boolean
function IntervalPoint.__le(a, b)
	return a.time <= b.time
end

return IntervalPoint
