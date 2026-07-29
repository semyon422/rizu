local View = require("gui.View")

---Scrolling base for virtualized lists made of fixed-height rows. Subclasses
---own item storage, hit testing, and batched rendering.
---@class gui.VirtualizedList : gui.View, gui.IScrollModel
---@operator call: gui.VirtualizedList
---@field item_height number
---@field gap number
---@field scroll_target number
---@field scroll_current number
---@field scroll_velocity number
---@field overscroll number
---@field protected drag_active boolean
---@field private drag_origin_y number
---@field private drag_origin_scroll number
---@field private last_drag_y number
---@field private last_drag_time number
local VirtualizedList = View + {}

VirtualizedList.SCROLL_DECAY = 0.01
VirtualizedList.SCROLL_EPSILON = 0.1
VirtualizedList.FLING_DECAY = 4
VirtualizedList.FLING_IDLE_DECAY = -math.log(0.95) * 1000
VirtualizedList.FLING_VELOCITY_EPSILON = 5
VirtualizedList.VELOCITY_RESPONSE = 20
VirtualizedList.FLING_STALE_TIME = 0.066
VirtualizedList.OVERSCROLL_LIMIT_RATIO = 0.35
VirtualizedList.OVERSCROLL_RESISTANCE_RATIO = 0.5
VirtualizedList.OVERSCROLL_RECOVERY_DECAY = 12
VirtualizedList.OVERSCROLL_EPSILON = 0.1

function VirtualizedList:new()
	View.new(self)
	self.handles_mouse_input = true
	self.drag_axis = "vertical"
	self:setClip(true)
	self.item_height = 0
	self.gap = 0
	self.scroll_target = 0
	self.scroll_current = 0
	self.scroll_velocity = 0
	self.overscroll = 0
	self.drag_active = false
	self.drag_origin_y = 0
	self.drag_origin_scroll = 0
	self.last_drag_y = 0
	self.last_drag_time = 0
end

---@return integer count
function VirtualizedList:getItemCount()
	error("not implemented")
end

---@return integer columns
function VirtualizedList:getColumnCount()
	return 1
end

---@return integer rows
function VirtualizedList:getRowCount()
	local columns = self:getColumnCount()
	assert(columns >= 1, "virtualized list must have at least one column")
	return math.ceil(self:getItemCount() / columns)
end

---@return number step
function VirtualizedList:getRowStep()
	return self.item_height + self.gap
end

---@return number size
function VirtualizedList:getScrollContentSize()
	local rows = self:getRowCount()
	if rows == 0 then
		return 0
	end
	return rows * self.item_height + (rows - 1) * self.gap
end

---@return number size
function VirtualizedList:getScrollViewportSize()
	return self.height
end

---@return number max_scroll
function VirtualizedList:getMaxScroll()
	return math.max(0, self:getScrollContentSize() - self:getScrollViewportSize())
end

---@return number position
function VirtualizedList:getScrollPosition()
	return math.min(math.max(self.scroll_current, 0), self:getMaxScroll())
end

---@param value number
---@return number value
function VirtualizedList:clampScroll(value)
	return math.min(math.max(value, 0), self:getMaxScroll())
end

---Stops fling and overscroll recovery before direct position control.
function VirtualizedList:stopScrollMotion()
	self.scroll_velocity = 0
	self.overscroll = 0
end

---@param position number
---@param immediate boolean?
function VirtualizedList:scrollTo(position, immediate)
	assert(type(position) == "number" and position == position
		and position > -math.huge and position < math.huge,
		"scroll position must be a finite number")
	self.scroll_target = self:clampScroll(position)
	if immediate then
		self.scroll_current = self.scroll_target
		self.overscroll = 0
	end
end

---@param screen_x number
---@param screen_y number
---@return number local_y
function VirtualizedList:getLocalY(screen_x, screen_y)
	local _, local_y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	return local_y
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function VirtualizedList:onMouseDown(e)
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
function VirtualizedList:onDragStart(e)
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
function VirtualizedList:updateDrag(screen_x, screen_y, event_time)
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
	local bounded_position = self:clampScroll(position)
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
end

---@param e gui.DragEvent
---@return boolean? handled
function VirtualizedList:onDrag(e)
	if not self.drag_active or e.button ~= 1 then
		return
	end
	self:updateDrag(e.x, e.y, e.time)
	return true
end

---@param e gui.DragEndEvent
---@return boolean? handled
function VirtualizedList:onDragEnd(e)
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
function VirtualizedList:onMouseUp(e)
	if e.button ~= 1 then
		return
	end
	self.drag_active = false
	return true
end

---@param e gui.ScrollEvent
---@return boolean handled
function VirtualizedList:onScroll(e)
	self.scroll_velocity = 0
	self:scrollTo(self.scroll_target - e.direction_y * self:getRowStep())
	return true
end

---@param dt number
function VirtualizedList:update(dt)
	local max_scroll = self:getMaxScroll()
	self.scroll_target = math.min(math.max(self.scroll_target, 0), max_scroll)
	self.scroll_current = math.min(math.max(self.scroll_current, 0), max_scroll)

	if not self.drag_active and self.overscroll ~= 0 then
		self.overscroll = self.overscroll * math.exp(-self.OVERSCROLL_RECOVERY_DECAY * dt)
		if math.abs(self.overscroll) < self.OVERSCROLL_EPSILON then
			self.overscroll = 0
		end
	end
	if not self.drag_active and math.abs(self.scroll_velocity) >= self.FLING_VELOCITY_EPSILON then
		local decay = math.exp(-self.FLING_DECAY * dt)
		local distance = self.scroll_velocity * (1 - decay) / self.FLING_DECAY
		local previous = self.scroll_current
		self:scrollTo(previous + distance, true)
		self.scroll_velocity = self.scroll_velocity * decay
		if self.scroll_current == previous or self.scroll_current == 0 or self.scroll_current == max_scroll then
			self.scroll_velocity = 0
		end
	elseif math.abs(self.scroll_velocity) < self.FLING_VELOCITY_EPSILON then
		self.scroll_velocity = 0
	end

	local difference = self.scroll_current - self.scroll_target
	if math.abs(difference) < self.SCROLL_EPSILON then
		self.scroll_current = self.scroll_target
	else
		self.scroll_current = self.scroll_target + difference * math.exp(-self.SCROLL_DECAY * dt * 1000)
	end
end

---Returns the visual position used by hit testing and batched rendering.
---@return number position
function VirtualizedList:getVisualScrollPosition()
	return self.scroll_current + self.overscroll
end

---Returns the one-based row range intersecting the viewport.
---@return integer first_row
---@return integer last_row
function VirtualizedList:getVisibleRowRange()
	local row_count = self:getRowCount()
	if row_count == 0 then
		return 1, 0
	end
	local row_step = self:getRowStep()
	assert(row_step > 0, "virtualized list row step must be positive")
	local scroll = self:getVisualScrollPosition()
	local first_row = math.max(1, math.floor(scroll / row_step) + 1)
	local last_row = math.min(row_count, math.floor((scroll + self.height) / row_step) + 1)
	return first_row, last_row
end

return VirtualizedList
