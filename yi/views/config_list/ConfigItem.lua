local class = require("class")
local math_util = require("math_util")

---@class yi.ConfigItem
---@operator call: yi.ConfigItem
local ConfigItem = class()

ConfigItem.label = "Unknown"
ConfigItem.width = 900
ConfigItem.height = 60
ConfigItem.hover_t = 0
ConfigItem.is_focused = false
ConfigItem.right_side_x = 550
ConfigItem.right_size_size = ConfigItem.width - ConfigItem.right_side_x - 12

function ConfigItem:onClick() end

---@param k "up" | "down" | "left" | "right"
function ConfigItem:onDirectionalKeyPressed(k) end

---@param dt number
function ConfigItem:update(dt)
	self.hover_t = math_util.clamp(self.hover_t + (self.is_focused and dt * 8 or -dt * 8), 0, 1)
end

local lg = love.graphics
local colored_string = {{0, 0, 0, 1}, ""}

---@param atlas love.Image
---@param quads {[string]: love.Quad}
---@param text_batch love.Text
---@param global_y number
function ConfigItem:draw(atlas, quads, text_batch, global_y)
	local cap = quads.config_background_cap
	local _, _, w, h = cap:getViewport()

	if self.hover_t > 0 then
		lg.setColor(0, 0, 0, self.hover_t)
		lg.draw(atlas, cap, -4, 0)
		lg.draw(atlas, cap, self.width + 4, 0, 0, -1, 1)
	end

	lg.setColor(1, 1, 1, 0.7 + self.hover_t * 0.3)
	lg.draw(atlas, cap)
	lg.draw(atlas, quads.pixel, w, 0, 0, self.width - w * 2, self.height)
	lg.draw(atlas, cap, self.width, 0, 0, -1, 1)
	colored_string[2] = self.label
	text_batch:addf(colored_string, math.huge, "left", 12, global_y + 6)
end

return ConfigItem
