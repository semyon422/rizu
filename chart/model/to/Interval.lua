local class = require("class")

---@class chart.Vertex
---@operator call: chart.Vertex
---@field point chart.IntervalPoint
---@field next chart.Vertex?
---@field prev chart.Vertex?
local Vertex = class()

---@param offset number
function Vertex:new(offset)
	self.offset = offset
end

---@return chart.Fraction
function Vertex:time()
	return self.point.time
end

---@return number
function Vertex:getDuration()
	local duration = (self.next:time() - self:time()):tonumber()
	if duration <= 0 then
		error("zero interval duration found: " .. tostring(self) .. ", " .. tostring(self.next))
	end
	return duration
end

---@return number
function Vertex:getBeatDuration()
	local a, b = self:getPair()
	return (b.offset - a.offset) / a:getDuration()
end

---@return number
function Vertex:getTempo()
	return 60 / self:getBeatDuration()
end

---@return chart.Vertex
---@return chart.Vertex
---@return boolean
function Vertex:getPair()
	local a = self
	local n = a.next
	if n then
		return a, n, false
	end
	return a.prev, a, true
end

---@return boolean
function Vertex:isSingle()
	return not self.prev and not self.next
end

---@param a chart.Vertex
---@return string
function Vertex.__tostring(a)
	return ("Vertex(%s)"):format(a.offset)
end

return Vertex
