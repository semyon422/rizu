local SettingView = require("yi.components.config.SettingView")
local TweenValue = require("ui.anim.TweenValue")
local Color = require("yi.Color")
local Painter = require("yi.Painter")

---@class yi.config.CheckboxParams
---@field atlas love.Image
---@field pixel love.Quad
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color ui.Color
---@field box_color ui.Color
---@field check_color ui.Color
---@field checkbox_size number
---@field line_width number
---@field gap number
---@field animation_duration number
---@field pulse_decay number
---@field text_idle_alpha_scale number
---@field text_active_alpha_scale number
---@field checked boolean
---@field on_change fun(checked: boolean)?

---@class yi.config.Checkbox : yi.config.SettingView
---@overload fun(params: yi.config.CheckboxParams): yi.config.Checkbox
---@field atlas love.Image
---@field pixel love.Quad
---@field font love.Font
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color ui.Color
---@field box_color ui.Color
---@field check_color ui.Color
---@field checkbox_size number
---@field line_width number
---@field gap number
---@field animation_duration number
---@field pulse_decay number
---@field checked_progress_value ui.anim.TweenValue
---@field checked_progress number
---@field click_pulse_value ui.anim.TweenValue
---@field click_pulse number
---@field text_idle_alpha_scale number
---@field text_active_alpha_scale number
---@field text_batch love.Text
local Checkbox = SettingView + {}

---@private
function Checkbox:rebuild()
	self.font = self.resources:getScaledFont(self.font_name, self.font_size, self.ui_scale)
	self.text_batch = love.graphics.newText(self.font, self.text)

	local text_w, text_h = self.text_batch:getDimensions()
	text_w = self:toLogicalSize(text_w)
	text_h = self:toLogicalSize(text_h)
	local content_width = self.checkbox_size + self.gap + text_w
	local content_height = math.max(self.checkbox_size, text_h)
	local left, top, right, bottom = self:getSettingInsets()
	local width = content_width + left + right
	local height = content_height + top + bottom
	local width_percent = self.width_percent
	local height_percent = self.height_percent
	self:setSize(width, height)
	self.width_percent = width_percent == nil and 1 or width_percent
	self.height_percent = height_percent
end

---@param params yi.config.CheckboxParams
function Checkbox:new(params)
	SettingView.new(self)
	self.atlas = assert(params.atlas, "Atlas is required")
	self.pixel = assert(params.pixel, "Pixel quad is required")
	self.resources = assert(params.resources, "Checkbox resources are required")
	self.font_name = assert(params.font_name, "Checkbox font_name is required")
	self.font_size = assert(params.font_size, "Checkbox font_size is required")
	self.text = assert(params.text, "Text is required")
	self.color = assert(params.color, "Color is required")
	self.box_color = assert(params.box_color, "Box color is required")
	self.check_color = assert(params.check_color, "Check color is required")
	self.checkbox_size = assert(params.checkbox_size, "Checkbox size is required")
	self.line_width = assert(params.line_width, "Line width is required")
	self.gap = assert(params.gap, "Gap is required")
	self.animation_duration = assert(params.animation_duration, "Animation duration is required")
	self.pulse_decay = assert(params.pulse_decay, "Pulse decay is required")
	self.text_idle_alpha_scale = assert(params.text_idle_alpha_scale, "Text idle alpha scale is required")
	self.text_active_alpha_scale = assert(params.text_active_alpha_scale, "Text active alpha scale is required")
	self.on_change = params.on_change
	assert(params.checked ~= nil, "Checked is required")
	self.checked = params.checked
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.is_focusable = true
	self.checked_progress = self.checked and 1 or 0
	self.checked_progress_value = TweenValue({
		value = self.checked_progress,
		duration = self.animation_duration,
	})
	self.click_pulse = 0
	self.click_pulse_value = TweenValue({
		value = 0,
		duration = self.pulse_decay > 0 and 1 / self.pulse_decay or 0,
	})
	self._frame_draw_color = {0, 0, 0, 1}
	self._text_draw_color = {0, 0, 0, 1}
	self:rebuild()
end

function Checkbox:onResolutionChanged()
	self:rebuild()
end

---@param checked boolean
---@return boolean
function Checkbox:setChecked(checked)
	checked = not not checked
	if self.checked == checked then
		return false
	end

	self.checked = checked
	if self.on_change then
		self.on_change(checked)
	end

	local changed = true
	if changed then
		self.checked_progress_value:set(checked and 1 or 0)
		self.click_pulse_value:snap(1)
		if self.pulse_decay > 0 then
			self.click_pulse_value:set(0)
		end
	end
	return changed
end

---@return boolean
function Checkbox:toggle()
	return self:setChecked(not self.checked)
end

---@param e ui.KeyDownEvent
function Checkbox:onKeyDown(e)
	if e.key == "return" then
		return self:toggle()
	end
end

---@param e ui.MouseClickEvent
function Checkbox:onMouseClick(e)
	if e.button == 1 then
		return self:toggle()
	end
end

---@param dt number
function Checkbox:update(dt)
	SettingView.update(self, dt)
	self.checked_progress = self.checked_progress_value:update(dt)
	self.click_pulse = self.click_pulse_value:update(dt)
end

function Checkbox:draw()
	local lg = love.graphics
	self:drawSettingBackground()
	local content_x, content_y = self:getSettingContentOrigin()
	local box_size = self.checkbox_size
	local line_width = self.line_width
	local _, content_h = self:getSettingContentSize()
	local box_y = content_y + math.floor((content_h - box_size) / 2)
	local progress = self.checked_progress
	local pulse = self.click_pulse
	local text_h = self:toLogicalSize(self.text_batch:getHeight())
	local text_x = content_x + box_size + self.gap
	local text_y = content_y + math.floor((content_h - text_h) / 2)
	local frame_color = Color.mix_to(self._frame_draw_color, self.box_color, self.check_color, progress)

	Painter.setPixelMode(true, content_x, box_y)
	local box_size_px = Painter.toPixelSize(box_size)
	local line_width_px = math.max(1, Painter.toPixelSize(line_width))
	local inner_offset_px = line_width_px * 2
	local inner_span_px = math.max(0, box_size_px - inner_offset_px * 2)
	local inner_size_px = math.max(0, math.floor(inner_span_px * progress * (1 + pulse * 0.12) + 0.5))

	lg.setColor(frame_color)
	lg.rectangle("fill", 0, 0, box_size_px, line_width_px)
	lg.rectangle("fill", 0, box_size_px - line_width_px, box_size_px, line_width_px)
	lg.rectangle("fill", 0, 0, line_width_px, box_size_px)
	lg.rectangle("fill", box_size_px - line_width_px, 0, line_width_px, box_size_px)

	if inner_size_px > 0 then
		local inner_x_px = inner_offset_px + math.floor((inner_span_px - inner_size_px) / 2)
		local inner_y_px = inner_offset_px + math.floor((inner_span_px - inner_size_px) / 2)
		lg.setColor(self.check_color)
		lg.rectangle("fill", inner_x_px, inner_y_px, inner_size_px, inner_size_px)
	end
	Painter.setPixelMode(false)

	local text_alpha_scale = (self.focused or self.mouse_over) and self.text_active_alpha_scale or self.text_idle_alpha_scale
	lg.setColor(Color.scale_alpha_to(self._text_draw_color, self.color, text_alpha_scale))
	Painter.drawText(self.text_batch, text_x, text_y)
end

return Checkbox
