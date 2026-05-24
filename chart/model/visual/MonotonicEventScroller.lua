local class = require("class")
local table_util = require("table_util")
local VisualPoint = require("chart.model.visual.VisualPoint")
local Point = require("chart.model.tp.Point")

---@class chart.MonotonicEventScroller
---@operator call: chart.MonotonicEventScroller
local MonotonicEventScroller = class()

---@param visual chart.Visual
function MonotonicEventScroller:new(visual)
	self.visual = visual
	self.points = visual.points
	self.visible_points = {}
	self.last_start = 1
	self.last_end = 0
	self.last_range = 0
	self.last_vt = -math.huge
end

---@param points chart.VisualPoint[]
---@param vt number
---@return integer
local function find_index_upper(points, vt)
	local low = 1
	local high = #points
	local ans = #points + 1
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if points[mid].visualTime > vt then
			ans = mid
			high = mid - 1
		else
			low = mid + 1
		end
	end
	return ans
end

function MonotonicEventScroller:generate()
	-- matches interface, but we do nothing here
end

function MonotonicEventScroller:scroll(currentTime, f)
	self.currentTime = currentTime
	self:update(f)
end

function MonotonicEventScroller:scale(range, f)
	self.last_range = range
	self:update(f)
end

function MonotonicEventScroller:update(f)
	if not self.currentTime then return end

	local points = self.points
	local visual = self.visual
	if not self.cvp then
		self.cvp = VisualPoint(Point())
	end
	local cvp = self.cvp
	cvp.point.absoluteTime = self.currentTime
	visual.interpolator:interpolate(points, cvp, "absolute")
	local current_vt = cvp.visualTime

	local range = self.last_range
	-- We use a half-open range (start_vt, end_vt] to match FullEventScroller behavior.
	-- This ensures that points are hidden exactly when they reach the boundary.
	local start_vt = current_vt - range
	local end_vt = current_vt + range

	local start_i = find_index_upper(points, start_vt)
	local end_i = find_index_upper(points, end_vt) - 1

	if start_i == self.last_start and end_i == self.last_end then
		return
	end

	local visible_points = self.visible_points

	-- Remove points that are no longer visible
	for i = self.last_start, self.last_end do
		if i < start_i or i > end_i then
			local vp = points[i]
			visible_points[vp] = nil
			if f then f(vp, -1) end
		end
	end

	-- Add points that became visible
	for i = start_i, end_i do
		if i < self.last_start or i > self.last_end then
			local vp = points[i]
			visible_points[vp] = true
			if f then f(vp, 1) end
		end
	end

	self.last_start = start_i
	self.last_end = end_i
end

return MonotonicEventScroller
