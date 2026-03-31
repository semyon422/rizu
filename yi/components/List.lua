local BaseList = require("ui.base.List")
local math_util = require("math_util")

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
local List = BaseList + {}

---@param view ui.View
---@param box ui.Box
---@param box_size_changed boolean
local function refresh_child_view(view, box, ui_scale, box_size_changed, scale_changed)
	local box_changed = view.box ~= box
	local child_scale_changed = view.ui_scale ~= ui_scale
	view.box = box
	if scale_changed or child_scale_changed then
		view.ui_scale = ui_scale
		view:onResolutionChanged()
	end
	local geometry_changed = view:syncBoxSize() or box_changed or scale_changed or child_scale_changed or box_size_changed
	if geometry_changed then
		view:onGeometryChanged()
	end
	view:updateTransform()
end

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
	self:setItems(params.items or {})
end

function List:onResolutionChanged()
	self._children_resolution_changed = true
end

---@param items ui.View[]
function List:setItems(items)
	self.views = items or {}
	self.items = self.views
	self:onGeometryChanged()
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
	self:onGeometryChanged()
end

---@param delta number
function List:scrollBy(delta)
	self:setTargetScrollPosition(self.target_scroll_position + delta)
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
	local y = self.padding_top

	for i = 1, index - 1 do
		local view = self.views[i]
		y = y + view.height + self.gap
	end

	return y
end

function List:ensureFocusedChildVisible()
	local child = self.focused_index and self.views[self.focused_index]
	if not child then
		self:setTargetScrollPosition(0)
		return
	end

	local viewport_height = math.max(0, self.height - self.padding_top - self.padding_bottom)
	local center = self:getItemOffset(self.focused_index) + child.height * 0.5
	self:setTargetScrollPosition(center - (self.padding_top + viewport_height * 0.5))
end

function List:onGeometryChanged()
	local children_resolution_changed = self._children_resolution_changed
	self._children_resolution_changed = false
	local inner_width = math.max(0, self.width - self.padding_left - self.padding_right)
	local inner_height = math.max(0, self.height - self.padding_top - self.padding_bottom)
	local box_size_changed = self.content_box.width ~= inner_width
		or self.content_box.height ~= inner_height
	self.content_box.x = self.padding_left
	self.content_box.y = self.padding_top
	self.content_box.width = inner_width
	self.content_box.height = inner_height

	local viewport_top = 0
	local viewport_bottom = self.height
	local y = self.padding_top - self.scroll_position
	local content_y = self.padding_top
	local content_height = self.padding_top + self.padding_bottom

	self.first_visible = #self.views + 1
	self.last_visible = 0

	for i, view in ipairs(self.views) do
		view.x = self.padding_left
		view.y = y
		refresh_child_view(view, self.content_box, self.ui_scale, box_size_changed, children_resolution_changed)

		local is_visible = y + view.height > viewport_top and y < viewport_bottom
		if is_visible then
			self.first_visible = math.min(self.first_visible, i)
			self.last_visible = math.max(self.last_visible, i)
		end

		content_height = math.max(content_height, content_y + view:getHeight() + self.padding_bottom)

		y = y + view.height
		content_y = content_y + view.height
		if i < #self.views then
			y = y + self.gap
			content_y = content_y + self.gap
		end
	end

	if self.last_visible == 0 then
		self.first_visible = 1
	end

	self.content_height = math.max(0, content_height)
	self:setTargetScrollPosition(self.target_scroll_position)

	local max_scroll = math.max(0, self.content_height - self.height)
	local clamped_scroll_position = math.max(0, math.min(self.scroll_position, max_scroll))
	if clamped_scroll_position ~= self.scroll_position then
		self.scroll_position = clamped_scroll_position
		self:onGeometryChanged()
	end
end

---@param dt number
function List:update(dt)
	local diff = self.target_scroll_position - self.scroll_position
	if math.abs(diff) > 0.001 then
		local t = 1 - math.exp(-self.scroll_animation_speed * dt)
		self.scroll_position = math_util.lerp(t, self.scroll_position, self.target_scroll_position)
		if math.abs(self.target_scroll_position - self.scroll_position) < 0.5 then
			self.scroll_position = self.target_scroll_position
		end
	end

	self:onGeometryChanged()

	for i = self.first_visible, self.last_visible do
		local view = self.views[i]
		if view then
			view:update(dt)
		end
	end
end

function List:draw()
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
