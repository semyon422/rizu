local Point = require("ncdk2.tp.Point")

---@class ncdk2.IntervalPoint: ncdk2.Point
---@operator call: ncdk2.IntervalPoint
---@field _measure ncdk2.Measure?
---@field measure ncdk2.Measure?
---@field _vertex ncdk2.Vertex?
---@field vertex ncdk2.Vertex
local IntervalPoint = Point + {}

---@param time ncdk.Fraction
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

---@param a ncdk2.IntervalPoint
---@return string
function IntervalPoint.__tostring(a)
	return ("IntervalPoint(%s)"):format(a.time)
end

---@param a ncdk2.IntervalPoint
---@param b ncdk2.IntervalPoint
---@return boolean
function IntervalPoint.__eq(a, b)
	return a.time == b.time
end

---@param a ncdk2.IntervalPoint
---@param b ncdk2.IntervalPoint
---@return boolean
function IntervalPoint.__lt(a, b)
	return a.time < b.time
end

---@param a ncdk2.IntervalPoint
---@param b ncdk2.IntervalPoint
---@return boolean
function IntervalPoint.__le(a, b)
	return a.time <= b.time
end

return IntervalPoint
