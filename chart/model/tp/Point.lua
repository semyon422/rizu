local IPoint = require("chart.model.tp.IPoint")
local ffi = require("ffi")
local bit = require("bit")

---@class chart.Point: chart.IPoint
---@operator call: chart.Point
---@field absoluteTime number
local Point = IPoint + {}

Point.absoluteTime = 0

---@param absoluteTime number
function Point:new(absoluteTime)
	self.absoluteTime = absoluteTime
end

local DoubleBits = ffi.typeof("union { double value; uint32_t words[2]; }")
local low_word = ffi.abi("le") and 0 or 1
local high_word = ffi.abi("le") and 1 or 0

---@return string
function Point:getAbsoluteTimeKey()
	-- Keep the type pun explicit and local. A shared int64_t buffer cast to a
	-- double pointer is miscompiled by LuaJIT in hot conversion loops.
	local bits = DoubleBits()
	bits.value = self.absoluteTime
	return bit.tohex(tonumber(bits.words[high_word])) .. bit.tohex(tonumber(bits.words[low_word]))
end

---@param point chart.Point
---@return boolean
function Point:compare(point)
	return self.absoluteTime < point.absoluteTime
end

---@param a chart.Point
---@return string
function Point.__tostring(a)
	return ("Point(%s)"):format(a.absoluteTime)
end

---@param a chart.Point
---@param b chart.Point
---@return boolean
function Point.__eq(a, b)
	return a.absoluteTime == b.absoluteTime
end

---@param a chart.Point
---@param b chart.Point
---@return boolean
function Point.__lt(a, b)
	return a.absoluteTime < b.absoluteTime
end

---@param a chart.Point
---@param b chart.Point
---@return boolean
function Point.__le(a, b)
	return a.absoluteTime <= b.absoluteTime
end

return Point
