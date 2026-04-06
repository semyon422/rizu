local BaseList = require("ui.base.List")
local TweenValue = require("ui.anim.TweenValue")

---@class yi.ListParams
---@field gap number?
---@field padding number|[number, number]|[number, number, number, number]?
---@field padding_x number?
---@field padding_y number?
---@field padding_left number?
---@field padding_right number?
---@field padding_top number?
---@field padding_bottom number?
---@field handles_mouse_input boolean?
---@field handles_keyboard_input boolean?
---@field wheel_step number?
---@field scroll_animation_speed number?
---@field items ui.View[]?
---@field scroll_position number?
---@field focused_index integer?

---@class yi.List : ui.List
---@overload fun(params: yi.ListParams?): yi.List
---@field items ui.View[]
---@field wheel_step number
---@field scroll_animation_speed number
---@field padding_left number
---@field padding_right number
---@field padding_top number
---@field padding_bottom number
---@field scroll_value ui.anim.TweenValue
local List = BaseList + {}

---@param params yi.ListParams?
function List:new(params)
	params = params or {}
	BaseList.new(self)

	local padding = params.padding
	local default_padding_x = 0
	local default_padding_y = 0
	local default_padding_left = nil
	local default_padding_right = nil
	local default_padding_top = nil
	local default_padding_bottom = nil

	if type(padding) == "number" then
		default_padding_x = padding
		default_padding_y = padding
	elseif type(padding) == "table" then
		if #padding == 2 then
			default_padding_x = padding[1] or 0
			default_padding_y = padding[2] or 0
		elseif #padding == 4 then
			default_padding_left = padding[1] or 0
			default_padding_top = padding[2] or 0
			default_padding_right = padding[3] or 0
			default_padding_bottom = padding[4] or 0
		end
	end

	local padding_x = params.padding_x or default_padding_x
	local padding_y = params.padding_y or default_padding_y
	self.gap = params.gap or 0
	self.padding_left = params.padding_left or padding_x
	self.padding_right = params.padding_right or padding_x
	self.padding_top = params.padding_top or padding_y
	self.padding_bottom = params.padding_bottom or padding_y
	if default_padding_left ~= nil then
		self.padding_left = params.padding_left or default_padding_left
		self.padding_top = params.padding_top or default_padding_top
		self.padding_right = params.padding_right or default_padding_right
		self.padding_bottom = params.padding_bottom or default_padding_bottom
	end
	self.handles_mouse_input = params.handles_mouse_input
	if self.handles_mouse_input == nil then
		self.handles_mouse_input = true
	end
	self.handles_keyboard_input = params.handles_keyboard_input
	if self.handles_keyboard_input == nil then
		self.handles_keyboard_input = true
	end
	self.wheel_step = params.wheel_step or 72
	self.scroll_animation_speed = params.scroll_animation_speed or 20
	self.focused_index = params.focused_index

	local scroll_position = params.scroll_position or 0
	self.scroll_position = scroll_position
	self.target_scroll_position = scroll_position
	self.scroll_value = TweenValue({
		value = scroll_position,
		duration = self.scroll_animation_speed > 0 and 3 / self.scroll_animation_speed or 0,
		easing = "outQuad",
	})
	self:setItems(params.items or {})
end

---@param items ui.View[]
function List:setItems(items)
	self.views = items or {}
	self.items = self.views
	self:invalidateLayout()
	if self.box then
		self:applyLayout()
	end
end

---@generic T: ui.View
---@param view T
---@return T
function List:addItem(view)
	local item = BaseList.addView(self, view)
	self.items = self.views
	return item
end

---@return number
function List:getScrollPosition()
	return self.scroll_position
end

---@param scroll_position number
function List:setScrollPosition(scroll_position)
	self:setTargetScrollPosition(scroll_position)
	self.scroll_position = self.target_scroll_position
	self.scroll_value:snap(self.scroll_position)
	self:invalidateVisibleLayout()
	if self.box then
		self:refreshVisibleLayout()
	end
end

---@param position number
---@return boolean changed
function List:setTargetScrollPosition(position)
	local changed = BaseList.setTargetScrollPosition(self, position)
	if changed then
		self.scroll_value:set(self.target_scroll_position)
	end
	return changed
end

---@param position number
function List:onTargetScrollPositionClamped(position)
	self.scroll_value:set(position)
end

---@param position number
function List:onScrollPositionClamped(position)
	self.scroll_value:snap(position)
end

---@param delta number
function List:scrollBy(delta)
	self:setTargetScrollPosition(self.target_scroll_position + delta)
end

---@return number
function List:getChildBaseX()
	return self.padding_left
end

---@return number
function List:getChildBaseY()
	return self.padding_top
end

---@return number
function List:getTrailingInset()
	return self.padding_bottom
end

---@return number
function List:getContentBoxWidth()
	return math.max(0, self.width - self.padding_left - self.padding_right)
end

---@return number
function List:getContentBoxHeight()
	return math.max(0, self.height - self.padding_top - self.padding_bottom)
end

---@param e ui.ScrollEvent
---@return boolean handled
function List:onScroll(e)
	self:scrollBy(-e.direction_y * self.wheel_step)
	return true
end

---@param index integer
---@return number
function List:getItemOffset(index)
	return BaseList.getItemOffset(self, index)
end

function List:ensureFocusedChildVisible()
	if self.box then
		self:ensureLayout()
	end

	local child = self.focused_index and self.views[self.focused_index]
	if not child then
		self:setTargetScrollPosition(0)
		return
	end

	local viewport_height = math.max(0, self.height - self.padding_top - self.padding_bottom)
	local center = self:getItemOffset(self.focused_index) + child.height * 0.5
	self:setTargetScrollPosition(center - (self.padding_top + viewport_height * 0.5))
end

---@param dt number
function List:update(dt)
	self:ensureVisibleLayout()

	local next_scroll_position = self.scroll_value:update(dt)
	if next_scroll_position ~= self.scroll_position then
		self.scroll_position = next_scroll_position
		self:invalidateVisibleLayout()
		self:refreshVisibleLayout()
	end

	for i = self.first_visible, self.last_visible do
		local view = self.views[i]
		if view then
			view:update(dt)
		end
	end
end

function List:draw()
	self:ensureVisibleLayout()

	love.graphics.push("all")

	local x1, y1 = self.transform:transformPoint(0, 0)
	local x2, y2 = self.transform:transformPoint(self.width, self.height)

	local left = math.min(x1, x2)
	local top = math.min(y1, y2)
	local right = math.max(x1, x2)
	local bottom = math.max(y1, y2)

	love.graphics.intersectScissor(
		math.floor(left + 0.5),
		math.floor(top + 0.5),
		math.max(0, math.floor(right - left + 0.5)),
		math.max(0, math.floor(bottom - top + 0.5))
	)

	for i = self.first_visible, self.last_visible do
		local view = self.views[i]
		if view then
			love.graphics.push("all")
			love.graphics.origin()
			love.graphics.applyTransform(view.transform)
			view:draw()
			love.graphics.pop()
		end
	end

	love.graphics.pop()
end

return List
