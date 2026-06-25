local View = require("gui.View")
local Painter = require("yi.Painter")
local Resources = require("yi.Resources")
local Sounds = require("yi.Sounds")

---@class yi.views.FooterButton : gui.View
---@operator call: yi.views.FooterButton
local FooterButton = View + {}

---@param bg_color gui.Color
---@param text_color gui.Color
---@param text string
---@param on_click function
function FooterButton:new(bg_color, text_color, text, on_click)
	View.new(self)
	self.atlas = Resources.atlas
	self.quad = Resources.quads.footer_button
	self.bg_color = bg_color
	self.text_color = text_color
	self.text = text
	self.font = Resources.getFont("regular", 24)
	self.on_click = on_click

	self.quad_width = Painter.getQuadWidth(self.quad)
	self.quad_height = Painter.getQuadHeight(self.quad)
	self:setSize(self.quad_width, self.quad_height)
	self.text_y = (self.quad_height - self.font:getHeight()) / 2

	self.handles_mouse_input = true
end

function FooterButton:onHover()
	Sounds.play("hover")
end

function FooterButton:onMouseClick(e)
	self.on_click()
	return true
end

function FooterButton:draw()
	local bg = self.bg_color
	local txt = self.text_color

	if self.mouse_over then
		bg = {1, 1, 1, 1}
		txt = {0, 0, 0, 1}
	end

	love.graphics.setColor(bg)
	love.graphics.draw(self.atlas, self.quad)

	Painter.snapToPixel()
	love.graphics.setColor(txt)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 0, self.text_y, self.quad_width, "center")
end

return FooterButton
