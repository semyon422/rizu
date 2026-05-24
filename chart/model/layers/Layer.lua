local class = require("class")
local table_util = require("table_util")
local Point = require("chart.model.tp.Point")

---@class chart.Layer
---@operator call: chart.Layer
---@field points {[string]: chart.Point}
---@field visuals {[string]: chart.Visual}
local Layer = class()

function Layer:new()
	self.points = {}
	self.visuals = {}
	self.testPoint = self:newPoint()
end

---@param ... any
---@return chart.Point
function Layer:newPoint(...)
	return Point(...)
end

function Layer:compute()
	for _, visual in pairs(self.visuals) do
		visual:compute()
	end
	table_util.clear(self.testPoint)
	self:validate()
end

---@param ... any
---@return chart.Point
function Layer:getPoint(...)
	self.testPoint:new(...)

	local points = self.points
	local key = tostring(self.testPoint)
	local point = points[key]
	if point then
		return point
	end

	point = self:newPoint(...)
	points[key] = point

	return point
end

---@return chart.Point[]
function Layer:getPointList()
	---@type chart.Point[]
	local points = {}
	for _, point in pairs(self.points) do
		table.insert(points, point)
	end
	table.sort(points)
	return points
end

function Layer:validate()
	local points = self:getPointList()
	for i = 1, #points - 1 do
		local p = points[i]
		local next_p = points[i + 1]
		if p.absoluteTime == next_p.absoluteTime then
			error(("time is equal: %s, %s"):format(p, next_p))
		elseif p.absoluteTime > next_p.absoluteTime then
			error(("time is not monotonic: %s, %s"):format(p, next_p))
		end
	end

	local points_map = self.points
	for _, visual in pairs(self.visuals) do
		for _, visualPoint in ipairs(visual.points) do
			if not points_map[tostring(visualPoint.point)] then
				error(("missing Point for %s"):format(visualPoint))
			end
		end
	end
end

function Layer:toInterval() end
function Layer:toAbsolute() end

return Layer
