local ConfigItem = require("yi.views.config_list.ConfigItem")
local Colors = require("yi.Colors")
local math_util = require("math_util")

---@class yi.ConfigSlider : yi.ConfigItem
---@operator call: yi.ConfigSlider
local Slider = ConfigItem + {}

---@param label string
---@param min number
---@param max number
---@param step number
---@param format (fun(v: number): string) | string
---@param get_value fun(): number
---@param set_value fun(v: number)
function Slider:new(label, min, max, step, format, get_value, set_value)
	self.label = label
	self.min = min
	self.max = max
	self.step = step
	self.format = format
	self.get_value = get_value
	self.set_value = set_value
	self.value = self.get_value()
	self.value_str = ""
	self.current_percent = 0
	self.target_percent = 0
	self:updateTargetPercent()
	self.current_percent = self.target_percent
end

function Slider:updateTargetPercent()
	self.target_percent = (self.value - self.min) / (self.max - self.min)
	if type(self.format) == "function" then
		self.value_str = self.format(self.value)
	else
		self.value_str = self.format:format(self.value)
	end
end

function Slider:onDirectionalKeyPressed(k)
	local dir = 0

	if k == "left" then
		dir = -1
	elseif k == "right" then
		dir = 1
	else
		return
	end

	local v = math_util.clamp(self.value + dir * self.step, self.min, self.max)
	v = math_util.round(v, self.step)
	self.set_value(v)
	self.value = self.get_value()
	self:updateTargetPercent()
end

function Slider:update(dt)
	ConfigItem.update(self, dt)
	local dest = self.target_percent
	local diff = dest - self.current_percent
	self.current_percent = self.current_percent + diff * dt * 10
end

local lg = love.graphics
local colored_string = {{0, 0, 0, 1}, ""}

function Slider:draw(atlas, quads, text_batch, global_y)
	ConfigItem.draw(self, atlas, quads, text_batch, global_y)

	lg.setColor(0, 0, 0, 0.7 + self.hover_t * 0.3)
	lg.draw(atlas, quads.config_background_cap, self.right_side_x, 10, 0, 0.7, 0.7)
	lg.draw(atlas, quads.pixel, self.right_side_x + 6, 10, 0, 326, 42)
	lg.draw(atlas, quads.config_background_cap, self.right_side_x + self.right_size_size, 10, 0, -0.7, 0.7)

	colored_string[2] = self.value_str
	text_batch:addf(colored_string, self.right_side_x - 10, "right", 0, global_y + 6)

	local c = Colors.cyan_400
	lg.setColor(c[1], c[2], c[3], 0.7 + self.hover_t * 0.3)

	local p = self.current_percent
	local size = math.max(math.floor((self.right_size_size - 16) * p) + 16, 16)

	lg.draw(atlas, quads.config_background_cap, self.right_side_x + 3, 13, 0, 0.6, 0.6)
	lg.draw(atlas, quads.pixel, self.right_side_x + 5 + 3, 13, 0, size - 16, 36)
	lg.draw(atlas, quads.config_background_cap, self.right_side_x - 3 + size, 13, 0, -0.6, 0.6)
end

return Slider
