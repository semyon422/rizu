local IVisualPoint = require("chart.model.visual.IVisualPoint")

---@class chart.VisualPoint: chart.IVisualPoint
---@operator call: chart.VisualPoint
---@field _expand chart.Expand?
---@field _velocity chart.Velocity?
---@field compare_index integer
local VisualPoint = IVisualPoint + {}

VisualPoint.visualTime = 0
VisualPoint.monotonicVisualTime = 0
VisualPoint.section = 0
VisualPoint.currentSpeed = 1
VisualPoint.localSpeed = 1
VisualPoint.globalSpeed = 1

---@param point chart.Point
function VisualPoint:new(point)
	self.point = point
end

---@param vp chart.VisualPoint?
---@return number
function VisualPoint:getVisualTime(vp)
	if not vp then
		return self.point.absoluteTime
	end
	if self.section ~= vp.section then
		return (self.section - vp.section) / 0
	end
	local globalSpeed = vp.globalSpeed
	local localSpeed = self.localSpeed
	return (self.visualTime - vp.visualTime) * globalSpeed * localSpeed + vp.point.absoluteTime
end

---@param currentSpeed number
---@param localSpeed number
---@param globalSpeed number
function VisualPoint:setSpeeds(currentSpeed, localSpeed, globalSpeed)
	self.currentSpeed = currentSpeed
	self.localSpeed = localSpeed
	self.globalSpeed = globalSpeed
end

---@param vp chart.VisualPoint
---@return boolean
function VisualPoint:compare(vp)
	if self.section ~= vp.section then
		return self.section < vp.section
	end
	if self.monotonicVisualTime ~= vp.monotonicVisualTime then
		return self.monotonicVisualTime < vp.monotonicVisualTime
	end
	if self.point.absoluteTime ~= vp.point.absoluteTime then
		return self.point.absoluteTime < vp.point.absoluteTime
	end
	return false
end

---@param a chart.VisualPoint
---@return string
function VisualPoint.__tostring(a)
	return ("VisualPoint(%s)"):format(a.point)
end

---@param a chart.VisualPoint
---@param b chart.VisualPoint
---@return boolean
function VisualPoint.__lt(a, b)
	if a.point.absoluteTime ~= b.point.absoluteTime then
		return a.point.absoluteTime < b.point.absoluteTime
	end
	return a.compare_index < b.compare_index
end

return VisualPoint
