local class = require("class")

---@class chart.IPoint
---@operator call: chart.IPoint
---@field absoluteTime number
local IPoint = class()

---@return number|chart.Fraction
function IPoint:getBeatModulo()
	return 0
end

---@return number
function IPoint:getBeatDuration()
	return 0
end

return IPoint
