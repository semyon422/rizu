local class = require("class")

---@class chart.VisualColumns
---@operator call: chart.VisualColumns
local VisualColumns = class()

-- automatically manages visual points for stacked notes

---@param visual chart.Visual
---@param shareColumns boolean?
function VisualColumns:new(visual, shareColumns)
	self.visual = visual
	self.shareColumns = shareColumns ~= false
	---@type {[ncdk2.Point]: ncdk2.VisualPoint[] | {[ncdk2.Column]: ncdk2.VisualPoint[]}}
	self.points = {}
	---@type {[ncdk2.Point]: {[ncdk2.Column]: integer}}
	self.indexes = {}
end

---@param point chart.Point
---@param column chart.Column
function VisualColumns:getPoint(point, column)
	local points = self.points
	local indexes = self.indexes

	points[point] = points[point] or {}
	indexes[point] = indexes[point] or {}
	local _columns = indexes[point]

	local _points = points[point]
	if not self.shareColumns then
		points[point][column] = points[point][column] or {}
		_points = points[point][column]
	end

	_columns[column] = (_columns[column] or 0) + 1
	local index = _columns[column]
	local vp = _points[index]
	if vp then
		return vp
	end

	vp = self.visual:newPoint(point)
	_points[index] = vp
	return vp
end

return VisualColumns
