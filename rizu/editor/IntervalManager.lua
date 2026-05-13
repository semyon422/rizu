local class = require("class")

---@class rizu.editor.IntervalManager
---@operator call: rizu.editor.IntervalManager
local IntervalManager = class()

---@param interval chartedit.Interval
function IntervalManager:grab(interval)
	self.grabbedInterval = interval
end

function IntervalManager:drop()
	self.grabbedInterval = nil
end

---@return boolean
function IntervalManager:isGrabbed()
	return self.grabbedInterval ~= nil
end

---@param time number
function IntervalManager:moveGrabbed(time)
	self.editorModel.layer.intervals:moveInterval(self.grabbedInterval, time)
end

---@param point chartedit.Point
---@return chartedit.Interval
function IntervalManager:split(point)
	local layer = self.editorModel.layer
	local p = layer.points:getPoint(point:unpack())
	layer.visuals.main:getPoint(p)
	return layer.intervals:splitInterval(p)
end

---@param point chartedit.Point
function IntervalManager:merge(point)
	self.editorModel.layer.intervals:mergeInterval(point)
end

---@param interval chartedit.Interval
---@param beats number
function IntervalManager:update(interval, beats)
	self.editorModel.layer.intervals:updateInterval(interval, beats)
end

return IntervalManager
