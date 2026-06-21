local View = require("gui.View")
local Painter = require("yi.Painter")
local Colors = require("yi.Colors")

---@class yi.LabelParams
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color gui.Color
---@field outline_color gui.Color
---@field outline number

---@class yi.Label : gui.View
---@operator call: yi.Label
local Label = View + {}

---@param params yi.LabelParams
function Label:new(params)
	View.new(self)
	self.font_name = assert(params.font_name, "Label font_name is required")
	self.font_size = assert(params.font_size, "Label font_size is required")
	self.color = params.color or Colors.text
	self.text = params.text or ""
	self.outline = params.outline or 0
	self.outline_color = params.outline_color or Colors.text_shadow
	self:setWidth(Painter.getFontWidth(self.text, self.font_size))
	self:setHeight(Painter.getFontHeight(self.font_size))
end

---@param text string
function Label:setText(text)
	self.text = text
	self:setWidth(Painter.getFontWidth(self.text, self.font_size))
	self:setHeight(Painter.getFontHeight(self.font_size))
	self:updateTransform()
end

local lg = love.graphics

function Label:draw()
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.setColor(self.color)
	Painter.setFontOutline(self.outline)
	Painter.setFontOutlineColor(self.outline_color)

	if self.font_name == "bold" then
		Painter.setFontThickness(0.45)
	else
		Painter.setFontThickness(0.5)
	end

	Painter.beginTextDrawing()
	Painter.setFontSize(self.font_size)
	Painter.print(self.text, math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
	Painter.endTextDrawing()
end

return Label
