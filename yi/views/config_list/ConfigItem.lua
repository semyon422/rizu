local class = require("class")

---@class yi.ConfigItem
---@operator call: yi.ConfigItem
local ConfigItem = class()

ConfigItem.label = "Unknown"
ConfigItem.width = 900
ConfigItem.height = 60

function ConfigItem:onClick() end

local lg = love.graphics
local colored_string = {{0, 0, 0, 1}, ""}

---@param atlas love.Image
---@param quads {[string]: love.Quad}
---@param text_batch love.Text
---@param global_y number
function ConfigItem:draw(atlas, quads, text_batch, global_y)
	local cap = quads.config_background_cap
	local _, _, w, h = cap:getViewport()
	lg.setColor(1, 1, 1, 0.7)
	lg.draw(atlas, cap)
	lg.draw(atlas, quads.pixel, w, 0, 0, self.width - w * 2, self.height)
	lg.draw(atlas, cap, self.width, 0, 0, -1, 1)
	colored_string[2] = self.label
	text_batch:addf(colored_string, math.huge, "left", 12, global_y + 6)
end

return ConfigItem
