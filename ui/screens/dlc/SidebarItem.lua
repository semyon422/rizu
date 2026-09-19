local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.screens.dlc.SidebarItem : gui.View
---@operator call: ui.screens.dlc.SidebarItem
local SidebarItem = View + {}

---@param text string
---@param on_click fun()
function SidebarItem:new(text, on_click)
	View.new(self)
	self.text = text
	self.on_click = on_click
	self.selected = false
	self.font = Resources.getFont("medium", 18)
	self.handles_mouse_input = true
	self:setSize(240, 44)
end

---@param selected boolean
function SidebarItem:setSelected(selected)
	self.selected = selected
end

function SidebarItem:onMouseClick(e)
	if e.button ~= 1 then return end
	self.on_click()
	return true
end

function SidebarItem:draw()
	if self.selected or self.mouse_over then
		Painter.setColorTable(self.selected and Colors.surface_raised or Colors.surface)
		Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	end
	if self.selected then
		Painter.setColorTable(Colors.accent)
		Resources.sprites.pixel:draw(0, 0, 0, 4, self.height)
	end
	Painter.setColorTable(self.selected and Colors.text or Colors.muted)
	love.graphics.setFont(self.font)
	love.graphics.print(self.text, 16, (self.height - self.font:getHeight()) / 2)
end

return SidebarItem
