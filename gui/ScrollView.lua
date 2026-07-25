local View = require("gui.View")

---@class gui.ScrollView : gui.View
---@operator call: gui.ScrollView
---@field content gui.View
---@field scroll_target number
---@field scroll_current number
---@field scroll_decay number Decay rate per millisecond
---@field scroll_step number Distance moved by one wheel tick
---@field private max_scroll number?
local ScrollView = View + {}

ScrollView.SCROLL_DECAY = 0.01
ScrollView.SCROLL_STEP = 64
ScrollView.SCROLL_EPSILON = 0.1

---@param content gui.View?
function ScrollView:new(content)
	View.new(self)
	self.clip = true
	self.handles_mouse_input = true
	self.scroll_target = 0
	self.scroll_current = 0
	self.scroll_decay = self.SCROLL_DECAY
	self.scroll_step = self.SCROLL_STEP
	self.max_scroll = nil
	self.content = content or View()
	self:add(self.content)
end

---@return number max_scroll
function ScrollView:getMaxScroll()
	return math.max(0, self.content.height - self.height)
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
	self.content:setOffset(0, -self.scroll_current)
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
		self.content:setOffset(0, -self.scroll_current)
	end
end

---@param e gui.ScrollEvent
---@return boolean handled
function ScrollView:onScroll(e)
	self:scrollTo(self.scroll_target - e.direction_y * self.scroll_step)
	return true
end

---@param dt number
function ScrollView:update(dt)
	self:refreshBounds()
	local difference = self.scroll_current - self.scroll_target
	if math.abs(difference) < self.SCROLL_EPSILON then
		if difference ~= 0 then
			self.scroll_current = self.scroll_target
			self.content:setOffset(0, -self.scroll_current)
		end
		return
	end
	self.scroll_current = self.scroll_target + difference * math.exp(-self.scroll_decay * dt * 1000)
	self.content:setOffset(0, -self.scroll_current)
end

return ScrollView
