local class = require("class")
local VisualEvents = require("chart.model.visual.VisualEvents")
local EventScroller = require("chart.model.visual.EventScroller")

---@class chart.FullEventScroller
---@operator call: chart.FullEventScroller
local FullEventScroller = class()

local start_po2 = -1 -- 0.5s

---@param points chart.VisualPoint[]
---@param lazy boolean?
function FullEventScroller:generate(points, lazy)
	self.points = points
	local duration = self:getVisualDuration(points)
	local end_po2 = start_po2
	if duration > 0 then
		end_po2 = math.max(math.ceil(math.log(duration, 2)), start_po2)
	end

	self.ve = VisualEvents()

	---@type chart.EventScroller[]
	self.scrollers = {}
	self.end_po2 = end_po2
	self.scroller_index = start_po2

	if not lazy then
		for i = start_po2, end_po2 do
			self:getScroller(i)
		end
	else
		self:getScroller(start_po2)
	end
end

---@param index integer
---@return chart.EventScroller
function FullEventScroller:getScroller(index)
	local scrollers = self.scrollers
	if not scrollers[index] then
		local range = 2 ^ index
		if index == self.end_po2 then
			range = math.huge
		end
		local events = self.ve:generate(self.points, {-range, range})
		local scroller = EventScroller(events)
		scrollers[index] = scroller
		if self.currentTime then
			scroller:scroll(self.currentTime)
		end
	end
	return scrollers[index]
end

---@param points chart.VisualPoint[]
---@return number
function FullEventScroller:getVisualDuration(points)
	if #points == 0 then
		return 0
	end
	local min_vt, max_vt = math.huge, -math.huge
	for _, vp in ipairs(points) do
		min_vt = math.min(min_vt, vp.visualTime)
		max_vt = math.max(max_vt, vp.visualTime)
	end
	return max_vt - min_vt
end

---@param currentTime number
---@param f fun(vp: chart.VisualPoint, action: -1|1)?
function FullEventScroller:scroll(currentTime, f)
	self.currentTime = currentTime
	local scrollers = self.scrollers
	local scroller_index = self.scroller_index
	for i, scroller in pairs(scrollers) do
		if i == scroller_index then
			scroller:scroll(currentTime, f)
		else
			scroller:scroll(currentTime)
		end
	end
end

---@param _old {[chart.VisualPoint]: true}
---@param _new {[chart.VisualPoint]: true}
---@return {[chart.VisualPoint]: true}
---@return {[chart.VisualPoint]: true}
local function map_update(_new, _old)
	---@type {[chart.VisualPoint]: true}, {[chart.VisualPoint]: true}
	local old, new = {}, {}
	for v in pairs(_new) do
		if not _old[v] then
			new[v] = true
		end
	end
	for v in pairs(_old) do
		if not _new[v] then
			old[v] = true
		end
	end
	return new, old
end

---@param range number
---@param f fun(vp: chart.VisualPoint, action: -1|1)
function FullEventScroller:scale(range, f)
	local index = self.scroller_index
	local new_index = math.ceil(math.log(range, 2))
	new_index = math.min(math.max(new_index, start_po2), self.end_po2)
	if new_index == index then
		return
	end

	local old_scroller = self:getScroller(index)
	local new_scroller = self:getScroller(new_index)

	self.scroller_index = new_index

	local new_ps, old_ps = map_update(new_scroller.visible_points, old_scroller.visible_points)
	for vp in pairs(old_ps) do
		f(vp, -1)
	end
	for vp in pairs(new_ps) do
		f(vp, 1)
	end
end

return FullEventScroller
