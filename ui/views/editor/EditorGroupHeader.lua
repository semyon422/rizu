local View = require("gui.View")
local EditorRow = require("ui.views.editor.EditorRow")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---Title of a group of editor rows, with a divider line above it.
---@class ui.views.editor.EditorGroupHeader : gui.View
---@operator call: ui.views.editor.EditorGroupHeader
---@field text string
---@field font love.Font
local EditorGroupHeader = View + {}

local HEIGHT = 36

---@param text string
---@param width number
function EditorGroupHeader:new(text, width)
	View.new(self)
	self.text = text
	self.font = Resources.getFont("medium", 16)
	self:setSize(width, HEIGHT)
end

function EditorGroupHeader:draw()
	Painter.snapToPixel()
	EditorRow.fillRect(Colors.outline, 0, 0, self.width, 1)
	local chevron = Resources.sprites.icon_chevron
	local chevron_width, chevron_height = chevron:getDimensions()
	local y = math.floor((HEIGHT - chevron_height) / 2) + 1
	Painter.setColorTable(Colors.accent)
	chevron:draw(-6, y)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.text, chevron_width - 6, math.floor((HEIGHT - self.font:getHeight()) / 2) + 1)
end

return EditorGroupHeader
