local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.HeaderButton : gui.View
---@operator call: ui.views.HeaderButton
---@field icon gui.Sprite
---@field on_click fun()?
local HeaderButton = View + {}

local SIZE = 50

---@param icon gui.Sprite
---@param on_click fun()?
function HeaderButton:new(icon, on_click)
	View.new(self)
	self.icon = icon
	self.on_click = on_click
	self.handles_mouse_input = true
	self:setSize(SIZE, SIZE)
end

---@param e gui.MouseClickEvent
function HeaderButton:onMouseClick(e)
	if e.button ~= 1 then return end
	if self.on_click then
		self.on_click()
	end
	return true
end

function HeaderButton:draw()
	Painter.snapToPixel()
	if self.mouse_over then
		Painter.setColorTable(Colors.hover)
		Resources.sprites.pixel:draw(0, 0, 0, SIZE, SIZE)
	end

	Painter.setColorTable(Colors.text)
	local icon_width, icon_height = self.icon:getDimensions()
	self.icon:draw((SIZE - icon_width) / 2, (SIZE - icon_height) / 2)
end

return HeaderButton
