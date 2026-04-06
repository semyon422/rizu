local SettingView = require("yi.components.config.SettingView")
local TweenValue = require("ui.anim.TweenValue")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Painter = require("yi.Painter")

---@class yi.config.PanelSelectItem
---@field text string

---@class yi.config.PanelSelectParams
---@field atlas love.Image
---@field pixel love.Quad
---@field resources yi.Resources
---@field label_font_name yi.FontName
---@field label_font_size integer
---@field item_font_name yi.FontName
---@field item_font_size integer
---@field text string
---@field items (string|yi.config.PanelSelectItem)[]
---@field format_item fun(item: string|yi.config.PanelSelectItem): string
---@field color ui.Color
---@field label_color ui.Color
---@field selected_color ui.Color
---@field frame_color ui.Color
---@field frame_idle_alpha number
---@field frame_active_alpha number
---@field label_idle_alpha_scale number
---@field label_active_alpha_scale number
---@field padding_x number
---@field padding_y number
---@field gap number
---@field panel_height number
---@field frame_width number
---@field selected_index integer
---@field scroll_animation_speed number
---@field frame_animation_speed number
---@field width number
---@field height number
---@field on_change fun(index: integer, item: string|yi.config.PanelSelectItem)?

---@class yi.config.PanelSelectLayoutItem
---@field text string
---@field x number
---@field width number

---@class yi.config.PanelSelect : yi.config.SettingView
---@overload fun(params: yi.config.PanelSelectParams): yi.config.PanelSelect
---@field atlas love.Image
---@field pixel love.Quad
---@field font love.Font
---@field item_font love.Font
---@field resources yi.Resources
---@field label_font_name yi.FontName
---@field label_font_size integer
---@field item_font_name yi.FontName
---@field item_font_size integer
---@field text string
---@field items (string|yi.config.PanelSelectItem)[]
---@field format_item fun(item: string|yi.config.PanelSelectItem): string
---@field color ui.Color
---@field label_color ui.Color
---@field selected_color ui.Color
---@field frame_color ui.Color
---@field frame_idle_alpha number
---@field frame_active_alpha number
---@field label_idle_alpha_scale number
---@field label_active_alpha_scale number
---@field padding_x number
---@field padding_y number
---@field gap number
---@field panel_height number
---@field frame_width number
---@field selected_index integer
---@field scroll_animation_speed number
---@field frame_animation_speed number
---@field on_change fun(index: integer, item: string|yi.config.PanelSelectItem)?
---@field scroll_value ui.anim.TweenValue
---@field scroll_position number
---@field target_scroll_position number
---@field content_width number
---@field layout_items yi.config.PanelSelectLayoutItem[]
---@field frame_x_value ui.anim.TweenValue
---@field frame_x number
---@field frame_width_value ui.anim.TweenValue
---@field frame_width_current number
---@field target_frame_x number
---@field target_frame_width number
---@field label_batch love.Text
---@field text_batch love.Text
local PanelSelect = SettingView + {}

---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
	return math.min(max, math.max(min, value))
end

---@param x number
---@param y number
---@param width number
---@param height number
local function apply_intersected_scissor(x, y, width, height)
	local lg = love.graphics
	local current_x, current_y, current_width, current_height = lg.getScissor()
	if not current_x then
		lg.setScissor(x, y, width, height)
		return
	end

	local left = math.max(x, current_x)
	local top = math.max(y, current_y)
	local right = math.min(x + width, current_x + current_width)
	local bottom = math.min(y + height, current_y + current_height)
	lg.setScissor(left, top, math.max(0, right - left), math.max(0, bottom - top))
end

---@private
function PanelSelect:rebuildBatches()
	self.font = self.resources:getScaledFont(self.label_font_name, self.label_font_size, self.ui_scale)
	self.item_font = self.resources:getScaledFont(self.item_font_name, self.item_font_size, self.ui_scale)
	self.label_batch = love.graphics.newText(self.font, self.text)
	self.text_batch = love.graphics.newText(self.item_font)
end

---@private
function PanelSelect:refreshSize()
	local left, top, right, bottom = self:getSettingInsets()
	local height = self:toLogicalSize(self.label_batch:getHeight()) + self.padding_y + self.panel_height + top + bottom
	local width_percent = self.width_percent
	local height_percent = self.height_percent
	self.height = height
	self.width_percent = width_percent
	self.height_percent = height_percent
end

---@private
function PanelSelect:requestRebuild()
	self._rebuild_requested = true
end

---@param params yi.config.PanelSelectParams
function PanelSelect:new(params)
	SettingView.new(self)
	self.atlas = assert(params.atlas, "Atlas is required")
	self.pixel = assert(params.pixel, "Pixel quad is required")
	self.resources = assert(params.resources, "PanelSelect resources are required")
	self.label_font_name = assert(params.label_font_name, "PanelSelect label_font_name is required")
	self.label_font_size = assert(params.label_font_size, "PanelSelect label_font_size is required")
	self.item_font_name = assert(params.item_font_name, "PanelSelect item_font_name is required")
	self.item_font_size = assert(params.item_font_size, "PanelSelect item_font_size is required")
	self.text = assert(params.text, "Text is required")
	self.items = assert(params.items, "Items are required")
	assert(#self.items > 0, "Items list must be non-empty")
	self.format_item = assert(params.format_item, "Format item function is required")
	self.color = assert(params.color, "Color is required")
	self.label_color = params.label_color or self.color
	self.selected_color = assert(params.selected_color, "Selected color is required")
	self.frame_color = assert(params.frame_color, "Frame color is required")
	self.frame_idle_alpha = clamp(assert(params.frame_idle_alpha, "PanelSelect frame_idle_alpha is required"), 0, 1)
	self.frame_active_alpha = clamp(assert(params.frame_active_alpha, "PanelSelect frame_active_alpha is required"), 0, 1)
	self.label_idle_alpha_scale = clamp(assert(params.label_idle_alpha_scale, "PanelSelect label_idle_alpha_scale is required"), 0, 1)
	self.label_active_alpha_scale = clamp(assert(params.label_active_alpha_scale, "PanelSelect label_active_alpha_scale is required"), 0, 1)
	self.padding_x = assert(params.padding_x, "Padding x is required")
	self.padding_y = assert(params.padding_y, "Padding y is required")
	self.gap = assert(params.gap, "Gap is required")
	self.panel_height = assert(params.panel_height, "Panel height is required")
	self.frame_width = assert(params.frame_width, "Frame width is required")
	self.selected_index = assert(params.selected_index, "Selected index is required")
	assert(self.selected_index >= 1 and self.selected_index <= #self.items, "Selected index is out of range")
	self.scroll_animation_speed = assert(params.scroll_animation_speed, "Scroll animation speed is required")
	self.frame_animation_speed = assert(params.frame_animation_speed, "Frame animation speed is required")
	self.width = assert(params.width, "Width is required")
	self.on_change = params.on_change
	self.scroll_position = 0
	self.target_scroll_position = 0
	self.scroll_value = TweenValue({
		value = 0,
		duration = self.scroll_animation_speed > 0 and 3 / self.scroll_animation_speed or 0,
		easing = "outQuad",
	})
	self.content_width = 0
	self.layout_items = {}
	self.frame_x = 0
	self.frame_width_current = 0
	self.target_frame_x = 0
	self.target_frame_width = 0
	self.frame_x_value = TweenValue({
		value = 0,
		duration = self.frame_animation_speed > 0 and 3 / self.frame_animation_speed or 0,
		easing = "outQuad",
	})
	self.frame_width_value = TweenValue({
		value = 0,
		duration = self.frame_animation_speed > 0 and 3 / self.frame_animation_speed or 0,
		easing = "outQuad",
	})
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.is_focusable = true
	self._label_draw_color = {0, 0, 0, 1}
	self._frame_draw_color = {0, 0, 0, 1}
	self._layout_width = nil
	self._layout_height = nil
	self:rebuildBatches()
	self:refreshSize()
	self:scrollToIndex(self.selected_index, true)
end

function PanelSelect:updateFrameTarget()
	local item = self.layout_items[self.selected_index]
	if not item then
		self.target_frame_x = 0
		self.target_frame_width = 0
		self.frame_x_value:set(0)
		self.frame_width_value:set(0)
		return
	end

	self.target_frame_x = item.x
	self.target_frame_width = item.width

	if self.frame_width_current == 0 then
		self.frame_x = self.target_frame_x
		self.frame_width_current = self.target_frame_width
		self.frame_x_value:snap(self.frame_x)
		self.frame_width_value:snap(self.frame_width_current)
		return
	end

	self.frame_x_value:set(self.target_frame_x)
	self.frame_width_value:set(self.target_frame_width)
end

---@return ui.Color
function PanelSelect:getFrameDrawColor()
	local color = self.focused and self.frame_color or Colors.white
	local active = self.focused or self.mouse_over
	local base_alpha = color[4] or 1
	local alpha = base_alpha * (active and self.frame_active_alpha or self.frame_idle_alpha)
	return Color.set(self._frame_draw_color, color[1], color[2], color[3], alpha)
end

function PanelSelect:onLayoutUpdate()
	self:rebuildBatches()
	self:refreshSize()
	self:requestRebuild()
	if self._rebuild_requested or self.width ~= self._layout_width or self.height ~= self._layout_height then
		local immediate_scroll = self._layout_width == nil or self._layout_height == nil or self._rebuild_requested
		self._layout_width = self.width
		self._layout_height = self.height
		self._rebuild_requested = false
		self:rebuild(immediate_scroll)
	end
end

---@param immediate_scroll boolean?
function PanelSelect:rebuild(immediate_scroll)
	self.layout_items = {}
	self.text_batch:clear()

	local content_x = self:getSettingContentOrigin()
	local _, panel_y, _, panel_h = self:getPanelRect()
	local x = content_x

	for i, item in ipairs(self.items) do
		local text = self.format_item(item)
		local text_w = self.text_batch:getFont():getWidth(text)
		local text_h = self.text_batch:getFont():getHeight()
		local logical_text_w = self:toLogicalSize(text_w)
		local logical_text_h = self:toLogicalSize(text_h)
		local panel_w = math.ceil(logical_text_w + self.padding_x * 2)
		local text_x = x + (panel_w - logical_text_w) / 2
		local text_y = panel_y + (panel_h - logical_text_h) / 2
		local text_color = (i == self.selected_index) and self.selected_color or self.color
		self.text_batch:addf({text_color, text}, math.huge, "left", self:toScreenSize(text_x), self:toScreenSize(text_y))

		self.layout_items[i] = {
			text = text,
			x = x,
			width = panel_w,
		}

		x = x + panel_w + self.gap
	end

	self.content_width = math.max(0, x - self.gap)
	self:updateFrameTarget()
	self:scrollToIndex(self.selected_index, immediate_scroll)
end

---@return number
function PanelSelect:getMaxScroll()
	local content_x = self:getSettingContentOrigin()
	local viewport_width = self:getSettingContentSize()
	return math.max(0, self.content_width - content_x - viewport_width)
end

---@param scroll_position number
function PanelSelect:setTargetScrollPosition(scroll_position)
	self.target_scroll_position = clamp(scroll_position, 0, self:getMaxScroll())
	self.scroll_value:set(self.target_scroll_position)
end

---@param index integer
---@param immediate boolean?
function PanelSelect:scrollToIndex(index, immediate)
	local item = self.layout_items[index]
	if not item then
		return
	end

	local content_x = self:getSettingContentOrigin()
	local viewport_width = self:getSettingContentSize()
	local target = item.x + item.width / 2 - (content_x + viewport_width / 2)
	self:setTargetScrollPosition(target)
	if immediate then
		self.scroll_position = self.target_scroll_position
		self.scroll_value:snap(self.scroll_position)
	end
end

---@param index integer
---@return boolean
function PanelSelect:setSelectedIndex(index)
	index = clamp(index, 1, #self.items)
	if self.selected_index == index then
		self:scrollToIndex(index)
		return false
	end

	self.selected_index = index
	self:rebuild(false)
	self:scrollToIndex(index)

	if self.on_change then
		self.on_change(index, self.items[index])
	end

	return true
end

---@param dt number
function PanelSelect:update(dt)
	SettingView.update(self, dt)
	self.scroll_position = self.scroll_value:update(dt)
	self.frame_x = self.frame_x_value:update(dt)
	self.frame_width_current = self.frame_width_value:update(dt)
end

---@param screen_x number
---@param screen_y number
---@return integer?
function PanelSelect:getIndexAt(screen_x, screen_y)
	local local_x, local_y = self.transform:inverseTransformPoint(screen_x, screen_y)
	local content_origin_x = self:getSettingContentOrigin()
	local viewport_width = self:getSettingContentSize()
	local _, panel_y, _, panel_h = self:getPanelRect()
	local content_x = local_x + self.scroll_position
	if local_x < content_origin_x or local_x > content_origin_x + viewport_width then
		return
	end

	if local_y < panel_y or local_y > panel_y + panel_h then
		return
	end

	for i, item in ipairs(self.layout_items) do
		if content_x >= item.x and content_x <= item.x + item.width then
			return i
		end
	end
end

---@param e ui.MouseClickEvent
function PanelSelect:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if not index then
		return
	end
	return self:setSelectedIndex(index)
end

---@param e ui.KeyDownEvent
function PanelSelect:onKeyDown(e)
	if e.key == "left" then
		return self:setSelectedIndex(self.selected_index - 1)
	elseif e.key == "right" then
		return self:setSelectedIndex(self.selected_index + 1)
	elseif e.key == "home" then
		return self:setSelectedIndex(1)
	elseif e.key == "end" then
		return self:setSelectedIndex(#self.items)
	end
end

function PanelSelect:draw()
	local lg = love.graphics
	local content_x, content_y = self:getSettingContentOrigin()
	local content_w = self:getSettingContentSize()
	local _, panel_y, _, panel_h = self:getPanelRect()
	local offset_x = -math.floor(self.scroll_position)
	local x1, y1 = self.transform:transformPoint(content_x, panel_y)
	local x2, y2 = self.transform:transformPoint(content_x + content_w, panel_y + panel_h)
	local scissor_left = math.floor(math.min(x1, x2))
	local scissor_top = math.floor(math.min(y1, y2))
	local scissor_right = math.ceil(math.max(x1, x2))
	local scissor_bottom = math.ceil(math.max(y1, y2))
	local scissor_x = scissor_left
	local scissor_y = scissor_top
	local scissor_width = math.max(0, scissor_right - scissor_left)
	local scissor_height = math.max(0, scissor_bottom - scissor_top)

	lg.push("all")
	self:drawSettingBackground()
	local label_active = self.focused or self.mouse_over
	local label_alpha_scale = label_active and self.label_active_alpha_scale or self.label_idle_alpha_scale
	lg.setColor(Color.scale_alpha_to(self._label_draw_color, self.label_color, label_alpha_scale))
	Painter.drawText(self.label_batch, content_x, content_y)
	apply_intersected_scissor(scissor_x, scissor_y, scissor_width, scissor_height)
	lg.translate(offset_x, 0)
	lg.setColor(self:getFrameDrawColor())
	Painter.drawPixelOutlineRect(self.frame_x, panel_y, self.frame_width_current, panel_h, self.frame_width)
	lg.setColor(1, 1, 1, 1)
	Painter.drawText(self.text_batch, 0, 0)
	lg.pop()
end

---@return number
---@return number
---@return number
---@return number
function PanelSelect:getPanelRect()
	local content_x, content_y = self:getSettingContentOrigin()
	local content_w, content_h = self:getSettingContentSize()
	local panel_y = content_y + self:toLogicalSize(self.label_batch:getHeight()) + self.padding_y
	local panel_h = math.max(0, math.min(self.panel_height, content_y + content_h - panel_y))
	return content_x, panel_y, content_w, panel_h
end

return PanelSelect
