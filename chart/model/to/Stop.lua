local class = require("class")

---@class chart.Stop
---@operator call: chart.Stop
local Stop = class()

---@param duration number|chart.Fraction
---@param isAbsolute boolean?
function Stop:new(duration, isAbsolute)
	self.duration = duration
	self.isAbsolute = isAbsolute
end

---@param a chart.Stop
---@return string
function Stop.__tostring(a)
	return ("Stop(%s)"):format(a.duration)
end

return Stop
