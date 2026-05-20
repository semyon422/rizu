local class = require("class")

---@class chart.Expand
---@operator call: chart.Expand
local Expand = class()

Expand.duration = 0

---@param duration number
function Expand:new(duration)
	self.duration = duration
end

---@param a chart.Expand
---@return string
function Expand.__tostring(a)
	return ("Expand(%s)"):format(a.duration)
end

return Expand
