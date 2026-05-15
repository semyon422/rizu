local View = require("ui.View")
local Painter = require("yi.Painter")

---@class yi.LabelParams
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color ui.Color

---@class yi.Label : ui.View
---@operator call: yi.Label
local Label = View + {}

---@private
function Label:rebuildText()
	self.font = self.resources:getScaledFont(self.font_name, self.font_size, self.ui_scale)
	self.text_batch = love.graphics.newText(self.font, self.text)
	local width, height = self.text_batch:getDimensions()
	self:setSize(self:toLogicalSize(width), self:toLogicalSize(height))
end

---@param params yi.LabelParams
function Label:new(params)
	View.new(self)
	self.resources = assert(params.resources, "Label resources are required")
	self.font_name = assert(params.font_name, "Label font_name is required")
	self.font_size = assert(params.font_size, "Label font_size is required")
	self.color = assert(params.color, "Color is required")
	self.text = assert(params.text, "Label text is required")
	self:rebuildText()
end

---@param text string
function Label:setText(text)
	self.text = text
	self:rebuildText()
end

function Label:onLayoutUpdate()
	self:rebuildText()
end

function Label:draw()
	love.graphics.setColor(self.color)
	Painter.drawText(self.text_batch, 0, 0)
end

return Label
