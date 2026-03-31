local SettingView = require("yi.components.config.SettingView")
local Color = require("yi.Color")
local Painter = require("yi.Painter")

---@class yi.config.SliderParams
---@field atlas love.Image
---@field pixel love.Quad
---@field resources yi.Resources
---@field label_font_name yi.FontName
---@field label_font_size integer
---@field value_font_name yi.FontName
---@field value_font_size integer
---@field text string
---@field color ui.Color
---@field value_color ui.Color
---@field accent_color ui.Color
---@field track_color ui.Color
---@field handle_color ui.Color
---@field value number
---@field min number
---@field max number
---@field step number
---@field width number
---@field track_height number
---@field handle_width number
---@field label_gap number
---@field animation_duration number
---@field value_format string
---@field format_value fun(value: number): string
---@field label_idle_alpha_scale number
---@field label_active_alpha_scale number
---@field value_idle_alpha_scale number
---@field value_active_alpha_scale number
---@field on_change fun(value: number)?

---@class yi.config.Slider : yi.config.SettingView
---@overload fun(params: yi.config.SliderParams): yi.config.Slider
---@field atlas love.Image
---@field pixel love.Quad
---@field label_font love.Font
---@field value_font love.Font
---@field resources yi.Resources
---@field label_font_name yi.FontName
---@field label_font_size integer
---@field value_font_name yi.FontName
---@field value_font_size integer
---@field text string
---@field color ui.Color
---@field value_color ui.Color
---@field accent_color ui.Color
---@field track_color ui.Color
---@field handle_color ui.Color
---@field value number
---@field min number
---@field max number
---@field step number
---@field track_width number
---@field track_height number
---@field handle_width number
---@field label_gap number
---@field animation_duration number
---@field value_format string
---@field format_value fun(value: number): string
---@field on_change fun(value: number)?
---@field dragging boolean
---@field displayed_progress number
---@field animation_from number
---@field target_progress number
---@field animation_t number
---@field label_idle_alpha_scale number
---@field label_active_alpha_scale number
---@field value_idle_alpha_scale number
---@field value_active_alpha_scale number
---@field label_batch love.Text
---@field value_batch love.Text
local Slider = SettingView + {}

---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
	return math.min(max, math.max(min, value))
end

---@param value number
---@param step number
---@param min number
---@return number
local function snap(value, step, min)
	if step <= 0 then
		return value
	end
	return min + math.floor(((value - min) / step) + 0.5) * step
end

---@param value number
---@param min number
---@param max number
---@return number
local function value_to_progress(value, min, max)
	local span = max - min
	if span == 0 then
		return 0
	end
	return (value - min) / span
end

---@param t number
---@return number
local function ease_out_cubic(t)
	return 1 - (1 - t) ^ 3
end

---@private
function Slider:rebuildBatches()
	self.label_font = self.resources:getScaledFont(self.label_font_name, self.label_font_size, self.ui_scale)
	self.value_font = self.resources:getScaledFont(self.value_font_name, self.value_font_size, self.ui_scale)
	self.label_batch = love.graphics.newText(self.label_font, self.text)
	self.value_batch = love.graphics.newText(self.value_font, self.format_value(self.value))
end

---@private
function Slider:refreshLayoutMetrics()
	local label_h = self:toLogicalSize(self.label_batch:getHeight())
	local value_h = self:toLogicalSize(self.value_batch:getHeight())
	local content_height = math.max(label_h, value_h) + self.label_gap + self.handle_width * 2
	local left, top, right, bottom = self:getSettingInsets()
	local height = content_height + top + bottom
	local width_percent = self.width_percent
	local height_percent = self.height_percent
	self.height = height
	self.width_percent = width_percent
	self.height_percent = height_percent
	self.track_width = math.max(0, self.width - left - right)
end

---@private
function Slider:rebuild()
	self:rebuildBatches()
	self:refreshLayoutMetrics()
end

---@param params yi.config.SliderParams
function Slider:new(params)
	SettingView.new(self)
	self.atlas = assert(params.atlas, "Atlas is required")
	self.pixel = assert(params.pixel, "Pixel quad is required")
	self.resources = assert(params.resources, "Slider resources are required")
	self.label_font_name = assert(params.label_font_name, "Slider label_font_name is required")
	self.label_font_size = assert(params.label_font_size, "Slider label_font_size is required")
	self.value_font_name = assert(params.value_font_name, "Slider value_font_name is required")
	self.value_font_size = assert(params.value_font_size, "Slider value_font_size is required")
	self.text = assert(params.text, "Text is required")
	self.color = assert(params.color, "Color is required")
	self.value_color = assert(params.value_color, "Value color is required")
	self.accent_color = assert(params.accent_color, "Accent color is required")
	self.track_color = assert(params.track_color, "Track color is required")
	self.handle_color = assert(params.handle_color, "Handle color is required")
	self.min = assert(params.min, "Min is required")
	self.max = assert(params.max, "Max is required")
	self.step = assert(params.step, "Step is required")
	self.width = assert(params.width, "Width is required")
	self.track_height = assert(params.track_height, "Track height is required")
	self.handle_width = assert(params.handle_width, "Handle width is required")
	self.label_gap = assert(params.label_gap, "Label gap is required")
	self.animation_duration = assert(params.animation_duration, "Animation duration is required")
	self.value_format = assert(params.value_format, "Value format is required")
	self.format_value = assert(params.format_value, "Format value function is required")
	self.label_idle_alpha_scale = assert(params.label_idle_alpha_scale, "Slider label_idle_alpha_scale is required")
	self.label_active_alpha_scale = assert(params.label_active_alpha_scale, "Slider label_active_alpha_scale is required")
	self.value_idle_alpha_scale = assert(params.value_idle_alpha_scale, "Slider value_idle_alpha_scale is required")
	self.value_active_alpha_scale = assert(params.value_active_alpha_scale, "Slider value_active_alpha_scale is required")
	assert(params.value ~= nil, "Value is required")
	self.on_change = params.on_change
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.is_focusable = true
	self.dragging = false

	assert(self.max >= self.min, "Max must be greater than or equal to min")
	local initial = clamp(params.value, self.min, self.max)
	self.value = snap(initial, self.step, self.min)
	self.displayed_progress = value_to_progress(self.value, self.min, self.max)
	self.animation_from = self.displayed_progress
	self.target_progress = self.displayed_progress
	self.animation_t = self.animation_duration
	self._label_draw_color = {0, 0, 0, 1}
	self._value_draw_color = {0, 0, 0, 1}
	self:rebuild()
end

---@private
function Slider:updateValueText()
	self.value_batch:set(self.format_value(self.value))
	self:refreshLayoutMetrics()
end

function Slider:onResolutionChanged()
	self:rebuild()
end

function Slider:onGeometryChanged()
	self:refreshLayoutMetrics()
end

---@return number
function Slider:getProgress()
	return value_to_progress(self.value, self.min, self.max)
end

---@param progress number
---@return boolean
function Slider:setProgress(progress)
	local span = self.max - self.min
	local value = self.min + clamp(progress, 0, 1) * span
	return self:setValue(value)
end

---@param value number
---@return boolean
function Slider:setValue(value)
	value = clamp(snap(value, self.step, self.min), self.min, self.max)
	if self.value == value then
		return false
	end
	self.value = value
	self.animation_from = self.displayed_progress
	self.target_progress = self:getProgress()
	self.animation_t = 0
	self:updateValueText()
	if self.on_change then
		self.on_change(value)
	end
	return true
end

---@param dt number
function Slider:update(dt)
	local duration = self.animation_duration
	if self.animation_t < duration then
		self.animation_t = math.min(duration, self.animation_t + dt)
		local t = duration > 0 and ease_out_cubic(self.animation_t / duration) or 1
		self.displayed_progress = self.animation_from + (self.target_progress - self.animation_from) * t
	else
		self.displayed_progress = self.target_progress
	end
end

---@param screen_x number
---@return number
function Slider:getProgressFromScreenX(screen_x)
	local local_x = self.transform:inverseTransformPoint(screen_x, 0)
	local content_x = self:getSettingContentOrigin()
	return clamp((local_x - content_x) / self.track_width, 0, 1)
end

---@param e ui.MouseDownEvent
function Slider:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	self.dragging = true
	return self:setProgress(self:getProgressFromScreenX(e.x))
end

---@param e ui.DragEvent|ui.DragStartEvent
function Slider:onDrag(e)
	if not self.dragging then
		return
	end
	return self:setProgress(self:getProgressFromScreenX(e.x))
end

---@param e ui.DragEndEvent
function Slider:onDragEnd(e)
	self.dragging = false
end

---@param e ui.MouseUpEvent
function Slider:onMouseUp(e)
	if e.button == 1 then
		self.dragging = false
	end
end

---@param e ui.ScrollEvent
function Slider:onScroll(e)
	if not e.control_pressed then
		return false
	end
	local delta = self.step > 0 and self.step or ((self.max - self.min) / 50)
	if delta <= 0 then
		return false
	end
	return self:setValue(self.value + e.direction_y * delta)
end

---@param e ui.KeyDownEvent
function Slider:onKeyDown(e)
	local delta = self.step > 0 and self.step or ((self.max - self.min) / 50)
	if e.key == "left" then
		return self:setValue(self.value - delta)
	elseif e.key == "right" then
		return self:setValue(self.value + delta)
	elseif e.key == "home" then
		return self:setValue(self.min)
	elseif e.key == "end" then
		return self:setValue(self.max)
	end
end

function Slider:draw()
	local lg = love.graphics
	self:drawSettingBackground()
	local content_x, content_y = self:getSettingContentOrigin()
	local progress = self.displayed_progress
	local label_h = self:toLogicalSize(self.label_batch:getHeight())
	local value_h = self:toLogicalSize(self.value_batch:getHeight())
	local labels_h = math.max(label_h, value_h)
	local track_width = self.track_width
	local track_span = math.max(0, track_width - self.handle_width)
	local handle_x_in_track = math.floor(progress * track_span + 0.5)
	local handle_center_x = handle_x_in_track + self.handle_width * 0.5
	local label_y = content_y + math.floor((labels_h - label_h) / 2) + 0.5
	local value_y = content_y + math.floor((labels_h - value_h) / 2) + 0.5
	local track_y = content_y + labels_h + self.label_gap
	local left_w = math.max(0, math.min(track_width, math.floor(handle_center_x + 0.5)))
	local right_x = left_w
	local right_w = math.max(0, track_width - right_x)

	local active = self.focused or self.mouse_over or self.dragging
	local label_alpha_scale = active and self.label_active_alpha_scale or self.label_idle_alpha_scale
	local value_alpha_scale = active and self.value_active_alpha_scale or self.value_idle_alpha_scale

	lg.setColor(Color.scale_alpha_to(self._label_draw_color, self.color, label_alpha_scale))
	Painter.drawText(self.label_batch, content_x, label_y)

	lg.setColor(Color.scale_alpha_to(self._value_draw_color, self.value_color, value_alpha_scale))
	Painter.drawText(
		self.value_batch,
		content_x + track_width - self:toLogicalSize(self.value_batch:getWidth()),
		value_y
	)

	if left_w > 0 then
		lg.setColor(self.accent_color)
		lg.draw(self.atlas, self.pixel, content_x, track_y, 0, left_w, self.track_height)
	end

	if right_w > 0 then
		lg.setColor(self.track_color)
		lg.draw(self.atlas, self.pixel, content_x + right_x, track_y, 0, right_w, self.track_height)
	end

	lg.setColor(self.handle_color)
	lg.draw(self.atlas, self.pixel, content_x + handle_x_in_track, track_y - self.handle_width, 0, self.handle_width, self.track_height + self.handle_width * 2)
end

return Slider
