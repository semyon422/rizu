local View = require("gui.View")
local Painter = require("gui.Painter")
local SpringValue = require("gui.anim.SpringValue")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")

local lg = love.graphics

---A light button of the row above Play: only its tinted icon shows until hover widens it to reveal
---the label. Its width and reveal are driven by ui.screens.main_menu_v2.MenuRow.
---@class ui.screens.main_menu_v2.MenuButton : gui.View
---@operator call: ui.screens.main_menu_v2.MenuButton
---@field icon gui.Sprite
---@field icon_color gui.Color
---@field on_click fun()
---@field text string
---@field font love.Font Picked to fit the row's cap, see fitLabel()
---@field shown_text string
---@field full_width number Width with the label revealed
---@field reveal gui.anim.SpringValue 0 icon only, 1 revealed
local MenuButton = View + {}

MenuButton.SIZE = 70 -- height, and the narrowest width
local ICON_SIZE = 22
local ICON_X = (MenuButton.SIZE - ICON_SIZE) / 2 -- smallest inset of the icon
local ICON_GAP = 10
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
	self.reveal = SpringValue({stiffness = 500, damping = 42})
	self:fitLabel(math.huge)
end

---@param max_width number Widest the button may get
function MenuButton:fitLabel(max_width)
	local room = max_width - ICON_X * 2 - ICON_SIZE - ICON_GAP
	self.font, self.shown_text = MenuButton.fit(self.text, room)
	self.full_width = math.ceil(ICON_X * 2 + ICON_SIZE + ICON_GAP + self.font:getWidth(self.shown_text))
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
	self.on_click()
	return true
end

function MenuButton:draw()
	if self.mouse_over then
		Painter.setColorRgb(1, 1, 1)
	else
		Painter.setColorTable(Colors.text)
	end
	lg.rectangle("fill", 0, 0, self.width, self.height)

	-- The icon slides from the center to its inset as the label comes in.
	local reveal = math.max(0, math.min(1, self.reveal:get()))
	-- Revealed, icon and label are centered together, or inset when the button is only as wide as they need.
	local content_width = ICON_SIZE + ICON_GAP + self.font:getWidth(self.shown_text)
	local revealed_x = math.max(ICON_X, (self.width - content_width) / 2)
	local icon_x = math.floor((self.width - ICON_SIZE) / 2 * (1 - reveal) + revealed_x * reveal + 0.5)
	local icon_width, icon_height = self.icon:getDimensions()
	Painter.setColorTable(self.icon_color)
	self.icon:draw(icon_x, ICON_X, 0, ICON_SIZE / icon_width, ICON_SIZE / icon_height)

	local opacity = reveal
	if opacity <= 0 then return end
	local font = self.font
	local sx, sy, sw, sh = Painter.addScissor(0, 0, self.width, self.height)
	Painter.setColorTable(Colors.panel)
	Painter.setOpacity(opacity)
	lg.setFont(font)
	lg.print(self.shown_text, icon_x + ICON_SIZE + ICON_GAP, math.floor((self.height - font:getHeight()) / 2))
	Painter.setOpacity(1)
	Painter.restoreScissor(sx, sy, sw, sh)
end

return MenuButton
