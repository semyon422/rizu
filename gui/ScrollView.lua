local View = require("gui.View")

---@class gui.ScrollView : gui.View, gui.IScrollModel
---@operator call: gui.ScrollView
---@field content gui.View
---@field scroll_target number
---@field scroll_current number
---@field scroll_decay number Decay rate per millisecond
---@field scroll_step number Distance moved by one wheel tick
---@field scroll_velocity number Current fling velocity in scroll units per second
---@field overscroll number Transient visual distance outside the scroll bounds
---@field private max_scroll number?
---@field private drag_active boolean
---@field private drag_origin_y number
---@field private drag_origin_scroll number
---@field private last_drag_y number
---@field private last_drag_time number
local ScrollView = View + {}

ScrollView.SCROLL_DECAY = 0.01
ScrollView.SCROLL_STEP = 64
ScrollView.SCROLL_EPSILON = 0.1
ScrollView.FLING_DECAY = 4
ScrollView.FLING_IDLE_DECAY = -math.log(0.95) * 1000
ScrollView.FLING_VELOCITY_EPSILON = 5
ScrollView.VELOCITY_RESPONSE = 20
ScrollView.FLING_STALE_TIME = 0.066
ScrollView.OVERSCROLL_LIMIT_RATIO = 0.35
ScrollView.OVERSCROLL_RESISTANCE_RATIO = 0.5
ScrollView.OVERSCROLL_RECOVERY_DECAY = 12
ScrollView.OVERSCROLL_EPSILON = 0.1

---@param content gui.View?
function ScrollView:new(content)
	View.new(self)
	self.clip = true
	self.handles_mouse_input = true
	self.drag_axis = "vertical"
	self.scroll_target = 0
	self.scroll_current = 0
	self.scroll_decay = self.SCROLL_DECAY
	self.scroll_step = self.SCROLL_STEP
	self.max_scroll = nil
	self.drag_active = false
	self.drag_origin_y = 0
	self.drag_origin_scroll = 0
	self.last_drag_y = 0
	self.last_drag_time = 0
	self.scroll_velocity = 0
	self.overscroll = 0
	self.content = content or View()
	self:add(self.content)
end

---@return number max_scroll
function ScrollView:getMaxScroll()
	return math.max(0, self.content.height - self.height)
end

---@return number position
function ScrollView:getScrollPosition()
	return math.min(math.max(self.scroll_current, 0), self:getMaxScroll())
end

---@return number size
function ScrollView:getScrollContentSize()
	return self.content.height
end

---@return number size
function ScrollView:getScrollViewportSize()
	return self.height
end

---@private
function ScrollView:applyScrollOffset()
	self.content:setOffset(0, -(self.scroll_current + self.overscroll))
	self:refreshCulling()
end

---@private
function ScrollView:refreshBounds()
	local max_scroll = self:getMaxScroll()
	if max_scroll == self.max_scroll then
		return
	end
	self.max_scroll = max_scroll
	self.scroll_target = math.min(math.max(self.scroll_target, 0), max_scroll)
	self.scroll_current = math.min(math.max(self.scroll_current, 0), max_scroll)
	self.overscroll = 0
	self:applyScrollOffset()
end

---Re-clamp and re-cull after a layout/tree rebuild, even when the extent did
---not change (descendant geometry may have changed).
---@package
function ScrollView:refreshAfterLayout()
	self.max_scroll = nil
	self:refreshBounds()
end

---@package
function ScrollView:refreshCulling()
	local viewport = self.clip_rect
	if not viewport then
		return
	end
	local first = self.content.flat_index
	local last = self.content.flat_subtree_end
	local screen = self.screen
	if not screen or not first or not last then
		return
	end
	local vx1, vy1 = viewport[1], viewport[2]
	local vx2, vy2 = vx1 + viewport[3], vy1 + viewport[4]
	for i = first, last do
		local view = screen.views[i]
		local x, y, width, height = view:getWorldBounds()
		local outside = x + width <= vx1 or x >= vx2 or y + height <= vy1 or y >= vy2
		local culls = view.viewport_culls
		if outside then
			if not culls then
				culls = {}
				view.viewport_culls = culls
			end
			culls[self] = true
		else
			if culls then
				culls[self] = nil
			end
		end
		local culled = false
		if culls then
			for _ in pairs(culls) do
				culled = true
				break
			end
		end
		local was_culled = bit.band(view.cull_mask, View.CULL_VIEWPORT) ~= 0
		if culled then
			view.cull_mask = bit.bor(view.cull_mask, View.CULL_VIEWPORT)
			if not was_culled and screen.inputs then
				screen.inputs:clearSubtree(view)
			end
		else
			view.cull_mask = bit.band(view.cull_mask, bit.bnot(View.CULL_VIEWPORT))
		end
	end
end

---@param position number
---@param immediate boolean?
function ScrollView:scrollTo(position, immediate)
	assert(type(position) == "number" and position == position
		and position > -math.huge and position < math.huge,
		"scroll position must be a finite number")
	self:refreshBounds()
	self.scroll_target = math.min(math.max(position, 0), self.max_scroll)
	if immediate then
		self.scroll_current = self.scroll_target
		self.overscroll = 0
		self:applyScrollOffset()
	end
end

---@param screen_x number
---@param screen_y number
---@return number local_y
function ScrollView:getLocalY(screen_x, screen_y)
	local _, local_y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	return local_y
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function ScrollView:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	self.drag_origin_y = self:getLocalY(e.x, e.y)
	self.drag_origin_scroll = self.scroll_current + self.overscroll
	self.last_drag_y = self.drag_origin_y
	self.last_drag_time = e.time
	self.scroll_velocity = 0
	return true
end

---@param e gui.DragStartEvent
---@return boolean? handled
function ScrollView:onDragStart(e)
	if e.button ~= 1 then
		return
	end
	self.drag_active = true
	self.drag_origin_y = self:getLocalY(e.press_x or e.x, e.press_y or e.y)
	self.drag_origin_scroll = self.scroll_current + self.overscroll
	self.last_drag_y = self.drag_origin_y
	self.last_drag_time = e.press_time or e.time
	self.scroll_velocity = 0
	self:updateDrag(e.x, e.y, e.time)
	return true
end

---@private
---@param screen_x number
---@param screen_y number
---@param event_time number
function ScrollView:updateDrag(screen_x, screen_y, event_time)
	local local_y = self:getLocalY(screen_x, screen_y)
	local elapsed = event_time - self.last_drag_time
	if elapsed > 0 and local_y ~= self.last_drag_y then
		local measured_velocity = (self.last_drag_y - local_y) / elapsed
		local response = 1 - math.exp(-self.VELOCITY_RESPONSE * elapsed)
		self.scroll_velocity = self.scroll_velocity + (measured_velocity - self.scroll_velocity) * response
		self.last_drag_y = local_y
		self.last_drag_time = event_time
	end
	local position = self.drag_origin_scroll - (local_y - self.drag_origin_y)
	local bounded_position = math.min(math.max(position, 0), self.max_scroll or self:getMaxScroll())
	local overflow = position - bounded_position
	local limit = self.height * self.OVERSCROLL_LIMIT_RATIO
	local resistance_distance = self.height * self.OVERSCROLL_RESISTANCE_RATIO
	self.scroll_target = bounded_position
	self.scroll_current = bounded_position
	if limit > 0 and resistance_distance > 0 then
		self.overscroll = overflow * limit / (math.abs(overflow) + resistance_distance)
	else
		self.overscroll = 0
	end
	self:applyScrollOffset()
end

---@param e gui.DragEvent
---@return boolean? handled
function ScrollView:onDrag(e)
	if not self.drag_active or e.button ~= 1 then
		return
	end
	self:updateDrag(e.x, e.y, e.time)
	return true
end

---@param e gui.DragEndEvent
---@return boolean? handled
function ScrollView:onDragEnd(e)
	if not self.drag_active or e.button ~= 1 then
		return
	end
	self.drag_active = false
	local idle_time = e.time - self.last_drag_time
	if idle_time > self.FLING_STALE_TIME then
		self.scroll_velocity = self.scroll_velocity * math.exp(-self.FLING_IDLE_DECAY * (idle_time - self.FLING_STALE_TIME))
	end
	if self.overscroll ~= 0 or math.abs(self.scroll_velocity) < self.FLING_VELOCITY_EPSILON then
		self.scroll_velocity = 0
	end
	return true
end

---@param e gui.MouseUpEvent
---@return boolean? handled
function ScrollView:onMouseUp(e)
	if e.button ~= 1 then
		return
	end
	self.drag_active = false
	return true
end

---@param e gui.ScrollEvent
---@return boolean handled
function ScrollView:onScroll(e)
	self.scroll_velocity = 0
	self:scrollTo(self.scroll_target - e.direction_y * self.scroll_step)
	return true
end

---@param dt number
function ScrollView:update(dt)
	self:refreshBounds()
	if not self.drag_active and self.overscroll ~= 0 then
		self.overscroll = self.overscroll * math.exp(-self.OVERSCROLL_RECOVERY_DECAY * dt)
		if math.abs(self.overscroll) < self.OVERSCROLL_EPSILON then
			self.overscroll = 0
		end
		self:applyScrollOffset()
	end
	if not self.drag_active and math.abs(self.scroll_velocity) >= self.FLING_VELOCITY_EPSILON then
		local decay = math.exp(-self.FLING_DECAY * dt)
		local distance = self.scroll_velocity * (1 - decay) / self.FLING_DECAY
		local previous = self.scroll_current
		self:scrollTo(previous + distance, true)
		self.scroll_velocity = self.scroll_velocity * decay
		if self.scroll_current == previous or self.scroll_current == 0 or self.scroll_current == self.max_scroll then
			self.scroll_velocity = 0
		end
	elseif math.abs(self.scroll_velocity) < self.FLING_VELOCITY_EPSILON then
		self.scroll_velocity = 0
	end
	local difference = self.scroll_current - self.scroll_target
	if math.abs(difference) < self.SCROLL_EPSILON then
		if difference ~= 0 then
			self.scroll_current = self.scroll_target
			self:applyScrollOffset()
		end
		return
	end
	self.scroll_current = self.scroll_target + difference * math.exp(-self.scroll_decay * dt * 1000)
	self:applyScrollOffset()
end

return ScrollView
