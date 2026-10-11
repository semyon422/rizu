local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.result_v2.JudgeCounts.Item
---@field name string
---@field count integer
---@field color gui.Color

---@class ui.screens.result_v2.JudgeCounts : gui.View
---@operator call: ui.screens.result_v2.JudgeCounts
---@field items ui.screens.result_v2.JudgeCounts.Item[]
---@field count_font love.Font
---@field name_font love.Font
local JudgeCounts = View + {}

function JudgeCounts:new()
	View.new(self)
	self.items = {}
	self.count_font = Resources.getFont("medium", 34)
	self.name_font = Resources.getFont("medium", 13)
	self:setHeight(self.count_font:getHeight() + 2 + self.name_font:getHeight())
end

---@param items ui.screens.result_v2.JudgeCounts.Item[]
function JudgeCounts:setItems(items)
	self.items = items
end

function JudgeCounts:draw()
	Painter.snapToPixel()
	local columns = #self.items
	if columns == 0 then
		return
	end
	local column_width = self.width / columns
	local name_y = self.count_font:getHeight() + 2
	for i, item in ipairs(self.items) do
		local x = (i - 1) * column_width
		love.graphics.setFont(self.count_font)
		Painter.setColorTable(item.color)
		love.graphics.print(tostring(item.count), x, 0)
		love.graphics.setFont(self.name_font)
		Painter.setColorTable(Colors.muted)
		love.graphics.print(item.name:upper(), x, name_y)
	end
end

return JudgeCounts
