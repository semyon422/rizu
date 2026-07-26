local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.views.IconButton : gui.View
---@operator call: ui.views.IconButton
---@field icon gui.Sprite
---@field on_click fun()?
local IconButton = View + {}

---@param icon gui.Sprite
---@param on_click fun()?
function IconButton:new(icon, on_click)
	View.new(self)
	self.background = Resources.sprites.background_icon_button
	self.icon = icon
	self.on_click = on_click

	local background_width, background_height = self.background:getDimensions()
	local icon_width, icon_height = icon:getDimensions()
	self:setSize(background_width, background_height)
	self.icon_x = (background_width - icon_width) / 2
	self.icon_y = (background_height - icon_height) / 2
	self.handles_mouse_input = true
end

---@param e gui.MouseClickEvent
function IconButton:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	if self.on_click then
		self.on_click()
	end
	Sounds.play("click")
	return true
end

---@param e gui.HoverEvent
function IconButton:onHover(e)
	Sounds.play("hover")
end

function IconButton:draw()
	local bg = self.mouse_over and Colors.accent or Colors.elements
	Painter.snapToPixel()
	Painter.setColorTable(bg)
	self.background:draw()
	Painter.setColorTable(Colors.text)
	self.icon:draw(self.icon_x, self.icon_y)
end

return IconButton
