local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.song_select.FooterSmallButton : gui.View
---@operator call: ui.screens.song_select.FooterSmallButton
local FooterSmallButton = View + {}

---@param icon gui.Sprite
---@param color gui.Color
---@param on_click function
function FooterSmallButton:new(icon, color, on_click)
	View.new(self)
	self.icon = assert(icon)
	self.color = assert(color)
	self.bg = Resources.sprites.footer_small_button
	self.on_click = on_click

	local iw, ih = self.icon:getDimensions()
	local bw, bh = self.bg:getDimensions()
	self.icon_x = (bw - iw) / 2
	self.icon_y = (bh - ih) / 2

	self:setSize(self.bg:getDimensions())
	self.handles_mouse_input = true
end

function FooterSmallButton:onMouseClick(e)
	if e.button == 1 then
		self.on_click()
		return true
	end
end

local black = {0, 0, 0, 1}
local white = {1, 1, 1, 1}

function FooterSmallButton:draw()
	local bg_color = self.color
	local text_color = Colors.text

	if self.mouse_over then
		bg_color = white
		text_color = black
	end

	Painter.setColorTable(bg_color)
	self.bg:draw()
	Painter.setColorTable(text_color)
	self.icon:draw(self.icon_x, self.icon_y)
end

return FooterSmallButton
