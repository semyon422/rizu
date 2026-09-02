local Textbox = require("ui.views.Textbox")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")

local lg = love.graphics

---@class ui.screens.song_select.SearchField : ui.views.Textbox
---@operator call: ui.screens.song_select.SearchField
local SearchField = Textbox + {}

local TEXT_X = 48

---@param params ui.views.TextboxParams?
function SearchField:new(params)
	Textbox.new(self, params)
	self.font = Resources.getFont("medium", 16)
end

function SearchField:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.surface)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)

	local icon = Resources.sprites.icon_search
	local icon_width, icon_height = icon:getDimensions()
	local icon_scale = math.min(20 / icon_width, 20 / icon_height)
	Painter.setColorTable(Colors.accent)
	icon:draw(14, (self.height - icon_height * icon_scale) / 2, 0, icon_scale, icon_scale)

	local text = self.model:getText()
	local text_y = (self.height - self.font:getHeight()) / 2
	Painter.setColorTable(text == "" and Colors.muted or Colors.text)
	lg.setFont(self.font)
	lg.print(text == "" and self.placeholder or text, TEXT_X, text_y)

	if self.focused then
		local left = self.model:getSplit()
		Painter.setColorTable(Colors.text)
		Resources.sprites.pixel:draw(TEXT_X + self.font:getWidth(left), text_y, 0, 2, self.font:getHeight())
	end
end

return SearchField
