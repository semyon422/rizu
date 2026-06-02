local ConfigItem = require("yi.views.config_list.ConfigItem")
local math_util = require("math_util")
local table_util = require("table_util")

---@class yi.ConfigDropdown : yi.ConfigItem
---@operator call: yi.ConfigDropdown
local Dropdown = ConfigItem + {}

local lg = love.graphics

---@param label string
---@param setting rizu.config.kinds.Choice
---@param cfg rizu.config.Config
function Dropdown:new(label, setting, cfg)
	self.label = label
	self.setting = setting
	self.cfg = cfg
	self.items = setting.options
	self.format = setting.format or tostring
	self.value_str = self.cfg:getString(setting)
	self.index = table_util.indexof(self.items, self.value_str)
	self:updateSelectedText()
end

function Dropdown:onDirectionalKeyPressed(k)
	local dir = 0

	if k == "left" then
		dir = -1
	elseif k == "right" then
		dir = 1
	else
		return
	end

	local i = math_util.clamp(self.index + dir, 1, #self.items)
	self.index = i
	self.cfg:setString(self.setting, self.items[i])
	self:updateSelectedText()
end

function Dropdown:updateSelectedText()
	if #self.items == 0 then
		self.value_str = "Error: Empty list"
		return
	end

	local v = self.items[self.index]
	if not v then
		self.value_str = "Error: Invalid index"
		return
	end

	self.value_str = self.format(v)
end

function Dropdown:draw(atlas, quads, text_batch, global_y)
	ConfigItem.draw(self, atlas, quads, text_batch, global_y)

	lg.setColor(0, 0, 0, 0.7 + self.hover_t * 0.3)
	lg.translate(self.right_side_x, 10)
	lg.scale(0.7)
	local is = 1 / 0.7
	lg.draw(atlas, quads.config_background_cap)
	lg.draw(atlas, quads.pixel, 8, 0, 0, 326 * is, 42 * is)
	lg.draw(atlas, quads.config_background_cap, self.right_size_size * is, 0, 0, -1, 1)

	text_batch:addf(self.value_str, math.huge, "left", self.right_side_x + 6, global_y + 13, 0, 0.8, 0.8)

	text_batch:addf(
		"v",
		math.huge,
		"left",
		self.right_side_x + self.right_size_size - 30,
		global_y + 11,
		0,
		1.1,
		0.8
	)
end

return Dropdown
