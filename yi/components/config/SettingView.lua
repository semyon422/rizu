local View = require("ui.View")
local Colors = require("yi.Colors")
local Color = require("yi.Color")

---@class yi.config.SettingView : ui.View
---@field setting_background_color ui.Color
---@field setting_border_color ui.Color
---@field setting_line_color ui.Color
---@field setting_line_focus_color ui.Color
---@field setting_border_width number
---@field setting_line_width number
---@field setting_padding_x number
---@field setting_padding_y number
---@field setting_active_t number
---@field setting_active_speed number
---@field setting_last_time number
local SettingView = View + {}

function SettingView:initSettingStyle()
	self.setting_background_color = Colors.black_60
	self.setting_border_color = Colors.slate_600
	self.setting_line_color = Colors.white_30
	self.setting_line_focus_color = Colors.cyan_400
	self.setting_border_width = 2
	self.setting_line_width = 4
	self.setting_padding_x = 12
	self.setting_padding_y = 10
	self.setting_active_t = 0
	self.setting_active_speed = 16
	self.setting_last_time = love.timer.getTime()
	self._setting_active_bg = {0, 0, 0, 1}
	self._setting_active_border = {0, 0, 0, 1}
	self._setting_bg = {0, 0, 0, 1}
	self._setting_border = {0, 0, 0, 1}
	self._setting_line = {0, 0, 0, 1}
end

function SettingView:new()
	View.new(self)
	self.width_percent = 1
	self:initSettingStyle()
end

---@return number
---@return number
---@return number
---@return number
function SettingView:getSettingInsets()
	local left = math.max(self.setting_border_width, self.setting_line_width) + self.setting_padding_x
	local top = self.setting_border_width + self.setting_padding_y
	local right = self.setting_border_width + self.setting_padding_x
	local bottom = self.setting_border_width + self.setting_padding_y
	return left, top, right, bottom
end

---@return number
---@return number
function SettingView:getSettingContentOrigin()
	local left, top = SettingView.getSettingInsets(self)
	return left, top
end

---@return number
---@return number
function SettingView:getSettingContentSize()
	local left, top, right, bottom = SettingView.getSettingInsets(self)
	return math.max(0, self.width - left - right), math.max(0, self.height - top - bottom)
end

function SettingView:drawSettingBackground()
	local lg = love.graphics
	local atlas = assert(self.atlas, "SettingView atlas is required")
	local pixel = assert(self.pixel, "SettingView pixel quad is required")
	local is_active = self.focused or self.mouse_over
	local now = love.timer.getTime()
	local dt = math.max(0, now - self.setting_last_time)
	self.setting_last_time = now
	local target_t = is_active and 1 or 0
	local speed = self.setting_active_speed
	local blend_t = 1 - math.exp(-speed * dt)
	self.setting_active_t = self.setting_active_t + (target_t - self.setting_active_t) * blend_t

	local inactive_bg = self.setting_background_color
	local active_bg = Color.copy_to(self._setting_active_bg, Colors.black)
	local inactive_border = self.setting_border_color
	local active_border = Color.brighten_to(self._setting_active_border, inactive_border, 1.2, 0.08)
	local inactive_line = self.setting_line_color
	local active_line = self.setting_line_focus_color

	local t = self.setting_active_t
	local bg = Color.mix_to(self._setting_bg, inactive_bg, active_bg, t)
	local border = Color.mix_to(self._setting_border, inactive_border, active_border, t)
	local line = Color.mix_to(self._setting_line, inactive_line, active_line, t)

	local w = math.max(0, self.width)
	local h = math.max(0, self.height)
	local b = self.setting_border_width
	local lw = self.setting_line_width

	lg.setColor(bg)
	lg.draw(atlas, pixel, 0, 0, 0, w, h)

	if b > 0 and w > 0 and h > 0 then
		lg.setColor(border)
		lg.draw(atlas, pixel, w - b, 0, 0, b, h)

		if t > 0 then
			local border_alpha = (border[4] or 1) * t
			lg.setColor(border[1], border[2], border[3], border_alpha)
			lg.draw(atlas, pixel, 0, 0, 0, w, b)
			lg.draw(atlas, pixel, 0, h - b, 0, w, b)
		end
	end

	if lw > 0 and h > 0 then
		lg.setColor(line)
		lg.draw(atlas, pixel, 0, 0, 0, lw, h)
	end
end

return SettingView
