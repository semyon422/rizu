local View = require("ui.View")
local ConfigItem = require("yi.views.config_list.ConfigItem")
local Checkbox = require("yi.views.config_list.Checkbox")
local Painter = require("yi.Painter")

---@class yi.ConfigList : ui.View
---@operator call: yi.ConfigList
---@field items yi.ConfigItem[]
---@field focus_index integer
local ConfigList = View + {}

---@param resources yi.Resources
function ConfigList:new(resources)
	View.new(self)
	self.resources = resources
	self.items = {}
	self.focus_index = 0
	self.scroll_position = 0

	local font = resources:getFont("regular", 36)
	self.text_batch = love.graphics.newTextBatch(font)

	table.insert(self.items, Checkbox("Checkbox", function() return false end, function() end))
	table.insert(self.items, ConfigItem())
	table.insert(self.items, ConfigItem())

	self:setSize(ConfigItem.width, 800)
end

function ConfigList:onKeyDown(e) end

local lg = love.graphics

function ConfigList:draw()
	local atlas, quads = self.resources.atlas, self.resources.quads
	local text_batch = self.text_batch
	local global_y = self.scroll_position
	local gap = 10

	text_batch:clear()
	lg.push()

	for _, v in ipairs(self.items) do
		lg.push("all")
		v:draw(atlas, quads, text_batch, global_y)
		lg.pop()

		local add_y = gap + v.height
		global_y = global_y + add_y
		lg.translate(0, add_y)
	end

	lg.pop()
	Painter.snapToPixel()
	lg.draw(text_batch)
end

return ConfigList
