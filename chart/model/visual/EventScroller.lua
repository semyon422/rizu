local class = require("class")

---@class chart.EventScroller
---@operator call: chart.EventScroller
local EventScroller = class()

---@param action -1|1
---@return true?
local function true_from_action(action)
	if action == 1 then
		return true
	end
end

---@param events chart.VisualEvent[]
function EventScroller:new(events)
	self.events = events
	self.offset = 0

	--- Only used by FullEventScroller
	---@type {[ncdk2.VisualPoint]: true}
	self.visible_points = {}
end

---@param time number
---@param f fun(vp: chart.VisualPoint, action: -1|1)?
function EventScroller:scroll(time, f)
	local events = self.events
	local visible_points = self.visible_points

	local event = events[self.offset + 1]
	while event and event.time <= time do
		local p, a = event.point, event.action
		if f then
			f(p, a)
		end
		visible_points[p] = true_from_action(a)
		self.offset = self.offset + 1
		event = events[self.offset + 1]
	end
end

return EventScroller
