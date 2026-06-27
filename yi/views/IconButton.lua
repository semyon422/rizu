local View = require("gui.View")
local Colors = require("yi.Colors")
local Painter = require("yi.Painter")
local Resources = require("yi.Resources")
local Sounds = require("yi.Sounds")

---@class yi.views.IconButton : gui.View
---@operator call: yi.views.IconButton
local IconButton = View + {}

---@param icon_quad love.Quad
---@param on_click function?
function IconButton:new(icon_quad, on_click)
	View.new(self)
	self.atlas = Resources.atlas
	self.background_quad = Resources.quads.background_icon_button
	self.icon_quad = icon_quad
	self.on_click = on_click

	local _, _, bw, bh = self.background_quad:getViewport()
	local _, _, w, h = self.icon_quad:getViewport()
	self:setSize(bw, bh)

	self.icon_x = (bw - w) / 2
	self.icon_y = (bh - h) / 2

	self.handles_mouse_input = true
end

function IconButton:onMouseClick(e)
	if self.on_click then
		self.on_click()
	end
	Sounds.play("click")
	return true
end

function IconButton:onHover(e)
	Sounds.play("hover")
end

function IconButton:draw()
	local bg = Colors.elements

	if self.mouse_over then
		bg = Colors.accent
	end

	love.graphics.setColor(bg)
	love.graphics.draw(self.atlas, self.background_quad)
	love.graphics.setColor(Colors.text)
	Painter.snapToPixel()
	love.graphics.draw(self.atlas, self.icon_quad, self.icon_x, self.icon_y)
end

return IconButton
