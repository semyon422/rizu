local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("ui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.views.IconButton : gui.View
---@operator call: ui.views.IconButton
---@field icon_quad love.Quad
---@field on_click fun()?
local IconButton = View + {}

---@param icon_quad love.Quad
---@param on_click fun()?
function IconButton:new(icon_quad, on_click)
	View.new(self)
	self.atlas = Resources.atlas
	self.background_quad = Resources.quads.background_icon_button
	self.icon_quad = icon_quad
	self.on_click = on_click

	local _, _, background_width, background_height = self.background_quad:getViewport()
	local _, _, icon_width, icon_height = icon_quad:getViewport()
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
	Painter.setOpacity(self.effective_opacity)
	Painter.setColorTable(bg)
	love.graphics.draw(self.atlas, self.background_quad)
	Painter.setColorTable(Colors.text)
	love.graphics.draw(self.atlas, self.icon_quad, self.icon_x, self.icon_y)
end

return IconButton
