local class = require("class")
local Fraction = require("chart.core.Fraction")

---@class chart.Measure
---@operator call: chart.Measure
local Measure = class()

Measure.offset = Fraction(0)

---@param offset chart.Fraction
function Measure:new(offset)
	self.offset = offset
end

---@param a chart.Measure
---@return string
function Measure.__tostring(a)
	return ("Measure(%s)"):format(a.offset)
end

return Measure
