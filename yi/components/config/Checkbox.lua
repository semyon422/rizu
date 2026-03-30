local BaseCheckbox = require("ui.base.Checkbox")
local SettingView = require("yi.components.config.SettingView")
local Color = require("yi.Color")

---@class yi.config.CheckboxParams
---@field atlas love.Image
---@field pixel love.Quad
---@field font love.Font
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

---@class yi.config.Checkbox : ui.Checkbox
---@overload fun(params: yi.config.CheckboxParams): yi.config.Checkbox
---@field atlas love.Image
---@field pixel love.Quad
---@field font love.Font
---@field text string
---@field color ui.Color
---@field box_color ui.Color
---@field check_color ui.Color
---@field checkbox_size number
---@field line_width number
---@field gap number
---@field animation_duration number
---@field pulse_decay number
---@field animation_from number
---@field checked_progress number
---@field target_progress number
---@field animation_t number
---@field click_pulse number
---@field text_idle_alpha_scale number
---@field text_active_alpha_scale number
---@field text_batch love.Text
local Checkbox = BaseCheckbox + SettingView + {}

---@param params yi.config.CheckboxParams
function Checkbox:new(params)
	BaseCheckbox.new(self)
	SettingView.initSettingStyle(self)
	self.atlas = assert(params.atlas, "Atlas is required")
	self.pixel = assert(params.pixel, "Pixel quad is required")
	self.font = assert(params.font, "Font is required")
	self.text = assert(params.text, "Text is required")
	self.color = assert(params.color, "Color is required")
	self.box_color = assert(params.box_color, "Box color is required")
	self.check_color = assert(params.check_color, "Check color is required")
	self.checkbox_size = assert(params.checkbox_size, "Checkbox size is required")
	self.line_width = assert(params.line_width, "Line width is required")
	self.gap = assert(params.gap, "Gap is required")
	self.animation_duration = assert(params.animation_duration, "Animation duration is required")
	self.pulse_decay = assert(params.pulse_decay, "Pulse decay is required")
	self.text_idle_alpha_scale = params.text_idle_alpha_scale or 0.72
	self.text_active_alpha_scale = params.text_active_alpha_scale or 1
	self.on_change = params.on_change
	assert(params.checked ~= nil, "Checked is required")
	self.checked = params.checked
	self.animation_from = self.checked and 1 or 0
	self.checked_progress = self.checked and 1 or 0
	self.target_progress = self.checked_progress
	self.animation_t = self.animation_duration
	self.click_pulse = 0
	self._frame_draw_color = {0, 0, 0, 1}
	self._text_draw_color = {0, 0, 0, 1}

	self.text_batch = love.graphics.newText(self.font, self.text)

	local text_w, text_h = self.text_batch:getDimensions()
	local content_width = self.checkbox_size + self.gap + text_w
	local content_height = math.max(self.checkbox_size, text_h)
	local left, top, right, bottom = self:getSettingInsets()
	local width = content_width + left + right
	local height = content_height + top + bottom
	self:setSize(width, height)
	self.width_percent = 1
end

---@param checked boolean
---@return boolean
function Checkbox:setChecked(checked)
	local changed = BaseCheckbox.setChecked(self, checked)
	if changed then
		self.animation_from = self.checked_progress
		self.target_progress = checked and 1 or 0
		self.animation_t = 0
		self.click_pulse = 1
	end
	return changed
end

function Checkbox:updateTransform()
	BaseCheckbox.updateTransform(self)
	local x, y = self.transform:transformPoint(0, 0)
	self.transform:translate(math.floor(x) - x, math.floor(y) - y)
end

---@param dt number
function Checkbox:update(dt)
	local duration = self.animation_duration
	if self.animation_t < duration then
		self.animation_t = math.min(duration, self.animation_t + dt)
		local t = duration > 0 and (self.animation_t / duration) or 1
		self.checked_progress = self.animation_from + (self.target_progress - self.animation_from) * t
	else
		self.checked_progress = self.target_progress
	end
	self.click_pulse = math.max(0, self.click_pulse - dt * self.pulse_decay)
end

function Checkbox:draw()
	local lg = love.graphics
	self:drawSettingBackground()
	local content_x, content_y = self:getSettingContentOrigin()
	local box_size = self.checkbox_size
	local line_width = self.line_width
	local _, content_h = self:getSettingContentSize()
	local box_y = content_y + math.floor((content_h - box_size) / 2)
	local inner_offset = line_width * 2
	local progress = self.checked_progress
	local pulse = self.click_pulse
	local inner_size = math.max(0, (box_size - inner_offset * 2) * progress * (1 + pulse * 0.12))
	local text_h = self.text_batch:getHeight()
	local text_x = content_x + box_size + self.gap
	local text_y = content_y + math.floor((content_h - text_h) / 2)
	local frame_color = Color.mix_to(self._frame_draw_color, self.box_color, self.check_color, progress)

	lg.setColor(frame_color)
	lg.draw(self.atlas, self.pixel, content_x, box_y, 0, box_size, line_width)
	lg.draw(self.atlas, self.pixel, content_x, box_y + box_size - line_width, 0, box_size, line_width)
	lg.draw(self.atlas, self.pixel, content_x, box_y, 0, line_width, box_size)
	lg.draw(self.atlas, self.pixel, content_x + box_size - line_width, box_y, 0, line_width, box_size)

	if inner_size > 0 then
		local inner_x = content_x + inner_offset + (box_size - inner_offset * 2 - inner_size) / 2
		local inner_y = box_y + inner_offset + (box_size - inner_offset * 2 - inner_size) / 2
		lg.setColor(self.check_color)
		lg.draw(self.atlas, self.pixel, inner_x, inner_y, 0, inner_size, inner_size)
	end

	local text_alpha_scale = (self.focused or self.mouse_over) and self.text_active_alpha_scale or self.text_idle_alpha_scale
	lg.setColor(Color.scale_alpha_to(self._text_draw_color, self.color, text_alpha_scale))
	-- 0.5 keeps label rendering aligned with the existing label component.
	lg.draw(self.text_batch, text_x, text_y + 0.5)
end

return Checkbox
