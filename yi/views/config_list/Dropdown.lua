local ConfigItem = require("yi.views.config_list.ConfigItem")
local math_util = require("math_util")

---@class yi.ConfigDropdown : yi.ConfigItem
---@operator call: yi.ConfigDropdown
local Dropdown = ConfigItem + {}

local lg = love.graphics

---@param label string
---@param items any[]
---@param format (fun(v: number): string)?
---@param get_value fun(): number
---@param set_value fun(v: number)
function Dropdown:new(label, items, format, get_value, set_value)
	self.label = label
	self.items = items
	self.format = format or tostring
	self.get_value = get_value
	self.set_value = set_value
	self.value = self.get_value()
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

	local i = math_util.clamp(self.value + dir, 1, #self.items)
	self.set_value(i)
	self.value = self.get_value()
	self:updateSelectedText()
end

function Dropdown:updateSelectedText()
	if #self.items == 0 then
		self.value_str = "Error: Empty list"
		return
	end

	local v = self.items[self.value]
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
