local ConfigItem = require("yi.views.config_list.ConfigItem")

---@class yi.ConfigCheckbox : yi.ConfigItem
---@operator call: yi.ConfigCheckbox
local Checkbox = ConfigItem + {}

---@param label string
---@param get_value fun(): boolean
---@param set_value fun(v: boolean)
function Checkbox:new(label, get_value, set_value)
	self.label = label
	self.get_value = get_value
	self.set_value = set_value

	self.toggled = self.get_value()
end

local lg = love.graphics
local colored_string = {{1, 1, 1, 1}, ""}

function Checkbox:draw(atlas, quads, text_batch, global_y)
	ConfigItem.draw(self, atlas, quads, text_batch, global_y)

	lg.setColor(0, 0, 0)
	lg.draw(atlas, quads.config_background_cap, self.width - 350, 10, 0, 0.7, 0.7)
	lg.draw(atlas, quads.pixel, self.width - 344, 10, 0, 80, 42)
	lg.draw(atlas, quads.config_background_cap, self.width - 260, 10, 0, -0.7, 0.7)

	if not self.toggled then
		colored_string[2] = "OFF"
		text_batch:addf(colored_string, math.huge, "left", self.width - 331, global_y + 12, 0, 0.8, 0.8)
	end
end

return Checkbox
