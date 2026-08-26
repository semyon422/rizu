local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.song_select.HeaderButton : gui.View
---@operator call: ui.screens.song_select.HeaderButton
---@field icon gui.Sprite
---@field on_click fun()?
local HeaderButton = View + {}

local WIDTH = 42
local HEIGHT = 50
local ICON_SIZE = 20

---@param icon gui.Sprite
---@param on_click fun()?
function HeaderButton:new(icon, on_click)
	View.new(self)
	self.icon = icon
	self.on_click = on_click
	self.handles_mouse_input = true
	self:setSize(WIDTH, HEIGHT)
end

---@param e gui.MouseClickEvent
function HeaderButton:onMouseClick(e)
	if e.button ~= 1 then return end
	if self.on_click then
		self.on_click()
	end
	return true
end

function HeaderButton:draw()
	Painter.snapToPixel()
	if self.mouse_over then
		Painter.setColorTable(Colors.surface_raised)
		Resources.sprites.pixel:draw(0, 0, 0, WIDTH, HEIGHT)
	end

	Painter.setColorTable(self.mouse_over and Colors.text or Colors.muted)
	local icon_width, icon_height = self.icon:getDimensions()
	local scale = math.min(ICON_SIZE / icon_width, ICON_SIZE / icon_height)
	self.icon:draw(
		(WIDTH - icon_width * scale) / 2,
		(HEIGHT - icon_height * scale) / 2,
		0, scale, scale
	)
end

return HeaderButton
