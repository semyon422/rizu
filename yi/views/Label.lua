local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")

---@class yi.LabelParams
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color gui.Color

---@class yi.Label : gui.View
---@operator call: yi.Label
local Label = View + {}

---@param params yi.LabelParams
function Label:new(params)
	View.new(self)
	self.font_name = assert(params.font_name, "Label font_name is required")
	self.font_size = assert(params.font_size, "Label font_size is required")
	self.font = Resources.getFont(self.font_name, self.font_size)
	self.color = params.color or Colors.text
	self.text = params.text or ""
	self:setWidth(self.font:getWidth(self.text))
	self:setHeight(self.font:getHeight())
end

---@param text string
function Label:setText(text)
	self.text = text
	self:setWidth(self.font:getWidth(self.text))
	self:setHeight(self.font:getHeight())
	self:updateTransform()
end

local lg = love.graphics

function Label:draw()
	Painter.snapToPixel()
	lg.setColor(self.color)
	lg.setFont(self.font)
	lg.print(self.text)
end

return Label
