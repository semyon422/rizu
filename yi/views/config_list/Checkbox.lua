local ConfigItem = require("yi.views.config_list.ConfigItem")
local Colors = require("yi.Colors")

---@class yi.ConfigCheckbox : yi.ConfigItem
---@operator call: yi.ConfigCheckbox
local Checkbox = ConfigItem + {}

---@param label string
---@param setting rizu.config.Setting
---@param cfg rizu.config.Config
function Checkbox:new(label, setting, cfg)
	self.label = label
	self.setting = setting
	self.cfg = cfg

	self.toggled = cfg:getBoolean(setting)
	self.target_alpha = self.toggled and 1 or 0
	self.current_alpha = self.target_alpha
end

function Checkbox:onClick()
	self.cfg:setBoolean(self.setting, not self.toggled)
	self.toggled = self.cfg:getBoolean(self.setting)
	self.target_alpha = self.toggled and 1 or 0
end

function Checkbox:update(dt)
	ConfigItem.update(self, dt)
	local dest = self.target_alpha
	local diff = dest - self.current_alpha
	self.current_alpha = self.current_alpha + diff * dt * 12
end

local lg = love.graphics
local colored_string = {{0, 0, 0, 1}, "ON"}

function Checkbox:draw(atlas, quads, text_batch, global_y)
	ConfigItem.draw(self, atlas, quads, text_batch, global_y)

	lg.setColor(0, 0, 0, 0.7 + self.hover_t * 0.3)
	lg.draw(atlas, quads.config_background_cap, self.right_side_x, 10, 0, 0.7, 0.7)
	lg.draw(atlas, quads.pixel, self.right_side_x + 6, 10, 0, 81 + 3, 42)
	lg.draw(atlas, quads.config_background_cap, self.right_side_x + 93 + 3, 10, 0, -0.7, 0.7)

	colored_string[1][4] = self.current_alpha
	text_batch:addf(colored_string, math.huge, "left", self.width - 324, global_y + 12, 0, 0.8, 0.8)

	local c = Colors.cyan_400
	lg.setColor(c[1], c[2], c[3], (0.7 + self.hover_t * 0.3) * self.current_alpha)

	lg.draw(atlas, quads.config_background_cap, self.right_side_x + 3, 13, 0, 0.6, 0.6)
	lg.draw(atlas, quads.pixel, self.right_side_x + 5 + 3, 13, 0, 80, 36)
	lg.draw(atlas, quads.config_background_cap, self.right_side_x + 90 + 3, 13, 0, -0.6, 0.6)
end

return Checkbox
