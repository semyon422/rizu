local class = require("class")

---@class chartedit.Vertex
---@operator call: chartedit.Vertex
---@field point chartedit.Point
---@field next chartedit.Vertex
---@field prev chartedit.Vertex
local Vertex = class()

---@param offset number
---@param beats integer
function Vertex:new(offset, beats)
	self.offset = offset
	self.beats = beats
end

---@return ncdk.Fraction
function Vertex:start()
	return self.point.time % 1
end

---@return number
function Vertex:startn()
	return self.point.time:tonumber() % 1
end

---@return ncdk.Fraction
function Vertex:_end()
	return self.next:start() + self.beats
end

---@return number
function Vertex:getDuration()
	local duration = self.next:startn() - self:startn() + self.beats
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

---@return chartedit.Vertex
---@return chartedit.Vertex
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

---@param a chartedit.Vertex
---@return string
function Vertex.__tostring(a)
	return ("Vertex(%s, %s)"):format(a.offset, a.beats)
end

---@param a chartedit.Vertex
---@param b chartedit.Vertex
---@return boolean
function Vertex.__eq(a, b)
	return a.offset == b.offset
end

---@param a chartedit.Vertex
---@param b chartedit.Vertex
---@return boolean
function Vertex.__lt(a, b)
	return a.offset < b.offset
end

---@param a chartedit.Vertex
---@param b chartedit.Vertex
---@return boolean
function Vertex.__le(a, b)
	return a.offset <= b.offset
end

return Vertex
