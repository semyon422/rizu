local class = require("class")

---@class chart.IVisualPoint
---@operator call: chart.IVisualPoint
---@field point chart.IPoint
---@field _expand chart.Expand?
---@field _velocity chart.Velocity?
---@field currentSpeed number
---@field localSpeed number
---@field globalSpeed number
local IVisualPoint = class()

---@param vp chart.IVisualPoint?
---@return number
function IVisualPoint:getVisualTime(vp)
	return 0
end

return IVisualPoint
