local class = require("class")

---@class ncdk2.Vertex
---@operator call: ncdk2.Vertex
---@field point ncdk2.IntervalPoint
---@field next ncdk2.Vertex?
---@field prev ncdk2.Vertex?
local Vertex = class()

---@param offset number
function Vertex:new(offset)
	self.offset = offset
end

---@return ncdk.Fraction
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

---@return ncdk2.Vertex
---@return ncdk2.Vertex
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

---@param a ncdk2.Vertex
---@return string
function Vertex.__tostring(a)
	return ("Vertex(%s)"):format(a.offset)
end

return Vertex
