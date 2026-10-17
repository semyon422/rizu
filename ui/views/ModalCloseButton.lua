local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.ModalCloseButton : ui.views.Button
---@operator call: ui.views.ModalCloseButton
local ModalCloseButton = Button + {}

local ICON_SIZE = 24
local GAP = 12
local PADDING = 12
local PRESSED_OFFSET = 1

---@param on_click fun()?
---@param text string?
function ModalCloseButton:new(on_click, text)
	Button.new(self, text or "Close", on_click, {font_name = "medium", font_size = 16})
	self:setSize(120, 48)
	self.content_color = {0, 0, 0, 1}
end

function ModalCloseButton:draw()
	local lg = love.graphics
	local hover = math.max(0, math.min(1, self.hover:get()))
	Painter.snapToPixel()
	if hover > 0.001 or self.pressed then
		Painter.setOpacity(self.pressed and 1 or hover)
		Painter.setColorRgb(1, 1, 1)
		local background = self.pressed and self.pressed_background or self.background
		background:draw(self.width, self.height)
	end

	for index = 1, 4 do
		self.content_color[index] = Colors.muted[index] + (Colors.text[index] - Colors.muted[index]) * hover
	end
	Painter.setOpacity(1)
	Painter.setColorTable(self.content_color)
	local pressed_offset = self.pressed and PRESSED_OFFSET or 0
	local icon = Resources.sprites.icon_x
	local icon_width, icon_height = icon:getDimensions()
	icon:draw(PADDING + (ICON_SIZE - icon_width) / 2, (self.height - icon_height) / 2 + pressed_offset)

	lg.setFont(self.font)
	lg.print(self.text, PADDING + ICON_SIZE + GAP, (self.height - self.font:getHeight()) / 2 + pressed_offset)
end

return ModalCloseButton
