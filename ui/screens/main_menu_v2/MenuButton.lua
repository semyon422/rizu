local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")

local lg = love.graphics

---A light full-width row of the column above Play: tinted icon, then the label.
---@class ui.screens.main_menu_v2.MenuButton : gui.View
---@operator call: ui.screens.main_menu_v2.MenuButton
---@field icon gui.Sprite
---@field icon_color gui.Color
---@field on_click fun()
---@field text string
---@field font love.Font Picked to fit the width, see onLayoutChanged()
---@field shown_text string
local MenuButton = View + {}

MenuButton.HEIGHT = 56
local ICON_SIZE = 22
local ICON_X = 22
local ICON_GAP = 14
local MAX_FONT_SIZE = 19
local MIN_FONT_SIZE = 14

---@param text string
---@param icon gui.Sprite
---@param icon_color gui.Color
---@param on_click fun()
function MenuButton:new(text, icon, icon_color, on_click)
	View.new(self)
	self.icon = icon
	self.icon_color = icon_color
	self.on_click = on_click
	self.text = text
	self.handles_mouse_input = true
	self:setPivot(0.5, 0.5)
	self.font, self.shown_text = MenuButton.fit(text, math.huge)
end

function MenuButton:onLayoutChanged()
	self.font, self.shown_text = MenuButton.fit(self.text, self.width - ICON_X * 2 - ICON_SIZE - ICON_GAP)
end

---Long translations shrink the font first, then lose their end to an ellipsis.
---@param text string
---@param width number Room for the label
---@return love.Font
---@return string
function MenuButton.fit(text, width)
	for size = MAX_FONT_SIZE, MIN_FONT_SIZE, -1 do
		local font = Resources.getFont("bold", size)
		if font:getWidth(text) <= width then
			return font, text
		end
	end
	local font = Resources.getFont("bold", MIN_FONT_SIZE)
	return font, ChartCarousel.fitText(font, text, width)
end

---@param e gui.HoverEvent
function MenuButton:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseDownEvent
function MenuButton:onMouseDown(e)
	if e.button ~= 1 then return end
	self:scaleTo(0.97, 0.97, 0.08, "OutQuad")
	return true
end

---@param e gui.MouseUpEvent
function MenuButton:onMouseUp(e)
	if e.button ~= 1 then return end
	self:scaleTo(1, 1, 0.12, "OutCubic")
	return true
end

---@param e gui.MouseClickEvent
function MenuButton:onMouseClick(e)
	if e.button ~= 1 then return end
	-- Leaving the screen drops the press, so onMouseUp may never come.
	self:scaleTo(1, 1, 0.12, "OutCubic")
	Sounds.play("click")
	self.on_click()
	return true
end

function MenuButton:draw()
	Painter.snapToPixel()
	if self.mouse_over then
		Painter.setColorRgb(1, 1, 1)
	else
		Painter.setColorTable(Colors.text)
	end
	lg.rectangle("fill", 0, 0, self.width, self.height)

	local icon_y = math.floor((self.height - ICON_SIZE) / 2)
	local icon_width, icon_height = self.icon:getDimensions()
	Painter.setColorTable(self.icon_color)
	self.icon:draw(ICON_X, icon_y, 0, ICON_SIZE / icon_width, ICON_SIZE / icon_height)

	local font = self.font
	Painter.setColorTable(Colors.panel)
	lg.setFont(font)
	lg.print(self.shown_text, ICON_X + ICON_SIZE + ICON_GAP, math.floor((self.height - font:getHeight()) / 2))
end

return MenuButton
