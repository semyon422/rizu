local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sprite = require("gui.Sprite")
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

local SPRITE_MODE = 1
local TEXT_MODE = 2

---@param bg_color gui.Color
---@param bg_sprite gui.Sprite
---@param content_color gui.Color
---@param content string | gui.Sprite
---@param on_click fun()
function FooterButton:new(bg_color, bg_sprite, content_color, content, on_click)
	View.new(self)
	self.bg_sprite = bg_sprite
	self.bg_color = bg_color
	self.content_color = content_color
	self.on_click = on_click

	local bg_w, bg_h = bg_sprite:getDimensions()
	local c_w, c_h = 0, 0

	if type(content) == "string" then
		self.font = Resources.getFont("regular", 24)
		self.text = content
		self.mode = TEXT_MODE
		c_w, c_h = self.font:getWidth(content), self.font:getHeight()
	elseif type(content) == "table" and Sprite * content then
		---@cast content gui.Sprite
		self.mode = SPRITE_MODE
		self.icon = content
		c_w, c_h = content:getDimensions()
	else
		error("forth parameter is not a string nor it's a sprite")
	end

	self.content_x = (bg_w - c_w) / 2
	self.content_y = (bg_h - c_h) / 2

	self.handles_mouse_input = true
	self:setSize(bg_w, bg_h)
end

---@param e gui.HoverEvent
function FooterButton:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseClickEvent
function FooterButton:onMouseClick(e)
	if e.button ~= 1 then return end
	if self.on_click then
		self.on_click()
	end
	Sounds.play("click")
	return true
end

local hover_bg = {1, 1, 1, 1}
local hover_content_color = {0, 0, 0, 1}

function FooterButton:draw()
	local bg = self.mouse_over and hover_bg or self.bg_color
	local content_color = self.mouse_over and hover_content_color or self.content_color
	Painter.snapToPixel()
	Painter.setColorTable(bg)
	self.bg_sprite:draw()
	Painter.setColorTable(content_color)

	if self.mode == TEXT_MODE then
		love.graphics.setFont(self.font)
		love.graphics.print(self.text, self.content_x, self.content_y)
	else
		self.icon:draw(self.content_x, self.content_y)
	end
end

return FooterButton
