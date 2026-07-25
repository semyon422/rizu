local View = require("gui.View")

---@class gui.ScrollView : gui.View
---@operator call: gui.ScrollView
---@field content gui.View
---@field scroll_target number
---@field scroll_current number
---@field scroll_decay number Decay rate per millisecond
---@field scroll_step number Distance moved by one wheel tick
---@field private max_scroll number?
---@field is_scroll_view true
local ScrollView = View + {}

ScrollView.SCROLL_DECAY = 0.01
ScrollView.SCROLL_STEP = 64
ScrollView.SCROLL_EPSILON = 0.1

---@param content gui.View?
function ScrollView:new(content)
	View.new(self)
	self.clip = true
	self.handles_mouse_input = true
	self.is_scroll_view = true
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
	self:refreshCulling()
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
		self.content:setOffset(0, -self.scroll_current)
		self:refreshCulling()
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
			self:refreshCulling()
		end
		return
	end
	self.scroll_current = self.scroll_target + difference * math.exp(-self.scroll_decay * dt * 1000)
	self.content:setOffset(0, -self.scroll_current)
	self:refreshCulling()
end

return ScrollView
