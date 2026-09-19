local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.screens.dlc.ContentTypeTab : gui.View
---@operator call: ui.screens.dlc.ContentTypeTab
local ContentTypeTab = View + {}

local HORIZONTAL_PADDING = 20

---@param text string
---@param on_click fun()
function ContentTypeTab:new(text, on_click)
	View.new(self)
	self.text = text
	self.on_click = on_click
	self.selected = false
	self.font = Resources.getFont("medium", 17)
	self.handles_mouse_input = true
	self:setSize(self.font:getWidth(text) + HORIZONTAL_PADDING * 2, 44)
end

---@param selected boolean
function ContentTypeTab:setSelected(selected)
	self.selected = selected
end

function ContentTypeTab:onMouseClick(e)
	if e.button ~= 1 then return end
	self.on_click()
	return true
end

function ContentTypeTab:draw()
	if self.selected or self.mouse_over then
		Painter.setColorTable(self.selected and Colors.surface_raised or Colors.surface)
		Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	end
	if self.selected then
		Painter.setColorTable(Colors.accent)
		Resources.sprites.pixel:draw(0, self.height - 4, 0, self.width, 4)
	end
	Painter.setColorTable(self.selected and Colors.text or Colors.muted)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 0, (self.height - self.font:getHeight()) / 2, self.width, "center")
end

return ContentTypeTab
