local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.FooterButton : gui.View
---@operator call: ui.screens.song_select.FooterButton
---@field sprite gui.Sprite
---@field bg_color gui.Color
---@field text_color gui.Color
---@field text string
---@field font love.Font
---@field on_click fun()
local FooterButton = View + {}

---@param bg_color gui.Color
---@param text_color gui.Color
---@param text string
---@param on_click fun()
function FooterButton:new(bg_color, text_color, text, on_click)
	View.new(self)
	self.sprite = Resources.sprites.footer_button
	self.bg_color = bg_color
	self.text_color = text_color
	self.text = text
	self.font = Resources.getFont("regular", 24)
	self.on_click = on_click
	self.sprite_width, self.sprite_height = self.sprite:getDimensions()
	self:setSize(self.sprite_width, self.sprite_height)
	self.text_y = (self.sprite_height - self.font:getHeight()) / 2
	self.handles_mouse_input = true
end

---@param e gui.HoverEvent
function FooterButton:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseClickEvent
function FooterButton:onMouseClick(e)
	if e.button ~= 1 then return end
	self.on_click()
	Sounds.play("click")
	return true
end

local hover_bg = {1, 1, 1, 1}
local hover_text_color = {0, 0, 0, 1}

function FooterButton:draw()
	local bg = self.mouse_over and hover_bg or self.bg_color
	local text_color = self.mouse_over and hover_text_color or self.text_color
	Painter.snapToPixel()
	Painter.setColorTable(bg)
	self.sprite:draw()
	Painter.setColorTable(text_color)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 0, self.text_y, self.sprite_width, "center")
end

return FooterButton
