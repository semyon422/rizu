local View = require("gui.View")
local Painter = require("ui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.FooterButton : gui.View
---@operator call: ui.screens.song_select.FooterButton
---@field atlas love.Image
---@field quad love.Quad
---@field bg_color gui.Color
---@field text_color gui.Color
---@field text string
---@field font love.Font
---@field on_click fun()
---@field quad_width number
---@field quad_height number
---@field text_y number
local FooterButton = View + {}

---@param bg_color gui.Color
---@param text_color gui.Color
---@param text string
---@param on_click fun()
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

---@param e gui.HoverEvent
function FooterButton:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseClickEvent
function FooterButton:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	self.on_click()
	Sounds.play("click")
	return true
end

local hover_bg = {1, 1, 1, 1}
local hover_text_color = {0, 0, 0, 1}

function FooterButton:draw()
	local bg = self.bg_color
	local text_color = self.text_color

	if self.mouse_over then
		bg = hover_bg
		text_color = hover_text_color
	end

	Painter.snapToPixel()
	Painter.setOpacity(self.render_opacity)
	Painter.setColorTable(bg)
	love.graphics.draw(self.atlas, self.quad)

	Painter.setColorTable(text_color)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 0, self.text_y, self.quad_width, "center")
end

return FooterButton
