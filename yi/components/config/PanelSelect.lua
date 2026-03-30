local SettingView = require("yi.components.config.SettingView")
local Colors = require("yi.Colors")
local Color = require("yi.Color")

---@class yi.config.PanelSelectItem
---@field text string

---@class yi.config.PanelSelectParams
---@field atlas love.Image
---@field pixel love.Quad
---@field font love.Font
---@field item_font love.Font
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
---@field scroll_position number
---@field target_scroll_position number
---@field content_width number
---@field layout_items yi.config.PanelSelectLayoutItem[]
---@field frame_x number
---@field frame_width_current number
---@field target_frame_x number
---@field target_frame_width number
---@field background_batch love.SpriteBatch
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

---@param params yi.config.PanelSelectParams
function PanelSelect:new(params)
	SettingView.new(self)
	self.atlas = assert(params.atlas, "Atlas is required")
	self.pixel = assert(params.pixel, "Pixel quad is required")
	self.font = assert(params.font, "Font is required")
	self.item_font = assert(params.item_font, "Item font is required")
	self.text = assert(params.text, "Text is required")
	self.items = assert(params.items, "Items are required")
	assert(#self.items > 0, "Items list must be non-empty")
	self.format_item = assert(params.format_item, "Format item function is required")
	self.color = assert(params.color, "Color is required")
	self.label_color = params.label_color or self.color
	self.selected_color = assert(params.selected_color, "Selected color is required")
	self.frame_color = assert(params.frame_color, "Frame color is required")
	self.frame_idle_alpha = clamp(params.frame_idle_alpha or 0.5, 0, 1)
	self.frame_active_alpha = clamp(params.frame_active_alpha or 0.85, 0, 1)
	self.label_idle_alpha_scale = clamp(params.label_idle_alpha_scale or 0.72, 0, 1)
	self.label_active_alpha_scale = clamp(params.label_active_alpha_scale or 1, 0, 1)
	self.padding_x = assert(params.padding_x, "Padding x is required")
	self.padding_y = assert(params.padding_y, "Padding y is required")
	self.gap = assert(params.gap, "Gap is required")
	self.panel_height = assert(params.panel_height, "Panel height is required")
	self.frame_width = assert(params.frame_width, "Frame width is required")
	self.selected_index = assert(params.selected_index, "Selected index is required")
	assert(self.selected_index >= 1 and self.selected_index <= #self.items, "Selected index is out of range")
	self.scroll_animation_speed = assert(params.scroll_animation_speed, "Scroll animation speed is required")
	self.frame_animation_speed = assert(params.frame_animation_speed, "Frame animation speed is required")
	self.on_change = params.on_change
	self.scroll_position = 0
	self.target_scroll_position = 0
	self.content_width = 0
	self.layout_items = {}
	self.frame_x = 0
	self.frame_width_current = 0
	self.target_frame_x = 0
	self.target_frame_width = 0
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.is_focusable = true

	self.background_batch = love.graphics.newSpriteBatch(self.atlas, math.max(1, #self.items))
	self.label_batch = love.graphics.newText(self.font, self.text)
	self.text_batch = love.graphics.newText(self.item_font)
	self._label_draw_color = {0, 0, 0, 1}
	self._frame_draw_color = {0, 0, 0, 1}

	local width = assert(params.width, "Width is required")
	local height = assert(params.height, "Height is required")
	self:setSize(width, height)
	self:rebuild()
	self:scrollToIndex(self.selected_index, true)
end

function PanelSelect:updateFrameTarget()
	local item = self.layout_items[self.selected_index]
	if not item then
		self.target_frame_x = 0
		self.target_frame_width = 0
		return
	end

	self.target_frame_x = item.x
	self.target_frame_width = item.width

	if self.frame_width_current == 0 then
		self.frame_x = self.target_frame_x
		self.frame_width_current = self.target_frame_width
	end
end

function PanelSelect:rebuildBackgroundBatch()
	self.background_batch:clear()

	if self.target_frame_width > 0 and self.frame_width > 0 then
		local _, panel_y, _, panel_h = self:getPanelRect()
		local x = self.frame_x
		local width = self.frame_width_current
		local frame = self.frame_width

		self.background_batch:setColor(1, 1, 1, 1)
		self.background_batch:add(self.pixel, x, panel_y, 0, width, frame)
		self.background_batch:add(self.pixel, x, panel_y + panel_h - frame, 0, width, frame)
		self.background_batch:add(self.pixel, x, panel_y, 0, frame, panel_h)
		self.background_batch:add(self.pixel, x + width - frame, panel_y, 0, frame, panel_h)
	end

	self.background_batch:setColor(1, 1, 1, 1)
	self.background_batch:flush()
end

---@return ui.Color
function PanelSelect:getFrameDrawColor()
	local color = self.focused and self.frame_color or Colors.white
	local active = self.focused or self.mouse_over
	local base_alpha = color[4] or 1
	local alpha = base_alpha * (active and self.frame_active_alpha or self.frame_idle_alpha)
	return Color.set(self._frame_draw_color, color[1], color[2], color[3], alpha)
end

function PanelSelect:updateTransform()
	SettingView.updateTransform(self)
	local x, y = self.transform:transformPoint(0, 0)
	self.transform:translate(math.floor(x) - x, math.floor(y) - y)
end

function PanelSelect:rebuild()
	self.layout_items = {}
	self.text_batch:clear()

	local content_x, content_y = self:getSettingContentOrigin()
	local _, panel_y, _, panel_h = self:getPanelRect()
	local x = content_x

	for i, item in ipairs(self.items) do
		local text = self.format_item(item)
		local text_w = self.text_batch:getFont():getWidth(text)
		local text_h = self.text_batch:getFont():getHeight()
		local panel_w = math.ceil(text_w + self.padding_x * 2)
		local text_x = x + (panel_w - text_w) / 2
		local text_y = panel_y + (panel_h - text_h) / 2
		local text_color = (i == self.selected_index) and self.selected_color or self.color
		self.text_batch:addf({text_color, text}, math.huge, "left", text_x, text_y)

		self.layout_items[i] = {
			text = text,
			x = x,
			width = panel_w,
		}

		x = x + panel_w + self.gap
	end

	self.content_width = math.max(0, x - self.gap)
	self:updateFrameTarget()
	self:rebuildBackgroundBatch()
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
	self:rebuild()
	self:scrollToIndex(index)

	if self.on_change then
		self.on_change(index, self.items[index])
	end

	return true
end

---@param dt number
function PanelSelect:update(dt)
	local diff = self.target_scroll_position - self.scroll_position
	if math.abs(diff) > 0.001 then
		local t = 1 - math.exp(-self.scroll_animation_speed * dt)
		self.scroll_position = self.scroll_position + diff * t
		if math.abs(self.target_scroll_position - self.scroll_position) < 0.5 then
			self.scroll_position = self.target_scroll_position
		end
	end

	local frame_t = 1 - math.exp(-self.frame_animation_speed * dt)
	local frame_changed = false

	if math.abs(self.target_frame_x - self.frame_x) > 0.001 then
		self.frame_x = self.frame_x + (self.target_frame_x - self.frame_x) * frame_t
		if math.abs(self.target_frame_x - self.frame_x) < 0.5 then
			self.frame_x = self.target_frame_x
		end
		frame_changed = true
	end

	if math.abs(self.target_frame_width - self.frame_width_current) > 0.001 then
		self.frame_width_current = self.frame_width_current + (self.target_frame_width - self.frame_width_current) * frame_t
		if math.abs(self.target_frame_width - self.frame_width_current) < 0.5 then
			self.frame_width_current = self.target_frame_width
		end
		frame_changed = true
	end

	if frame_changed then
		self:rebuildBackgroundBatch()
	end
end

---@param screen_x number
---@param screen_y number
---@return integer?
function PanelSelect:getIndexAt(screen_x, screen_y)
	local local_x, local_y = self.transform:inverseTransformPoint(screen_x, screen_y)
	local content_origin_x, content_origin_y = self:getSettingContentOrigin()
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
	local screen_x, screen_y = self.transform:transformPoint(content_x, panel_y)
	local scissor_x = math.floor(screen_x)
	local scissor_y = math.floor(screen_y)
	local scissor_width = math.ceil(content_w)
	local scissor_height = math.ceil(panel_h)

	lg.push("all")
	self:drawSettingBackground()
	local label_active = self.focused or self.mouse_over
	local label_alpha_scale = label_active and self.label_active_alpha_scale or self.label_idle_alpha_scale
	lg.setColor(Color.scale_alpha_to(self._label_draw_color, self.label_color, label_alpha_scale))
	lg.draw(self.label_batch, content_x, content_y + 0.5)
	apply_intersected_scissor(scissor_x, scissor_y, scissor_width, scissor_height)
	lg.translate(offset_x, 0)
	lg.setColor(self:getFrameDrawColor())
	lg.draw(self.background_batch)
	lg.setColor(1, 1, 1, 1)
	lg.draw(self.text_batch, 0, 0.5)
	lg.pop()
end

---@return number
---@return number
---@return number
---@return number
function PanelSelect:getPanelRect()
	local content_x, content_y = self:getSettingContentOrigin()
	local content_w, content_h = self:getSettingContentSize()
	local panel_y = content_y + self.label_batch:getHeight() + self.padding_y
	local panel_h = math.max(0, math.min(self.panel_height, content_y + content_h - panel_y))
	return content_x, panel_y, content_w, panel_h
end

return PanelSelect
