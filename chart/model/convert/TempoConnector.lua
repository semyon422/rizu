local class = require("class")
local math_util = require("math_util")
local Fraction = require("chart.core.Fraction")

---@class chart.TempoConnector
---@operator call: chart.TempoConnector
local TempoConnector = class()

---@param denom number
---@param merge_time number
function TempoConnector:new(denom, merge_time)
	self.denom = denom
	self.merge_time = merge_time
end

---@param o_1 number
---@param l_1 number
---@param o_2 number
---@return chart.Fraction
---@return boolean
---@return integer
function TempoConnector:connect(o_1, l_1, o_2)
	local duration = o_2 - o_1
	local beats = duration / l_1

	local merge_time = self.merge_time

	local _beats = math_util.round(beats)
	if math.abs(_beats * l_1 - duration) <= merge_time then
		if _beats == 0 then
			_beats = 1
		end
		return Fraction(_beats), false, _beats
	end

	if beats * l_1 - merge_time <= l_1 / self.denom then
		return Fraction(1), false, 1
	end

	local f = Fraction(beats, self.denom, "floor")
	if beats - f:tonumber() <= merge_time then
		f = f - Fraction(1, self.denom)
	end

	return f, true, f[2] == 1 and f[1] + 1 or f:ceil()
end

return TempoConnector
