local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.LabelParams
---@field font_name ui.FontName
---@field font_size ui.FontSize|integer
---@field text string?
---@field color gui.Color?
---@field align "left"|"center"|"right"?

---@class ui.views.Label : gui.View
---@operator call: ui.views.Label
---@field font love.Font
---@field text string
---@field color gui.Color
---@field align "left"|"center"|"right"
local Label = View + {}

---@param params ui.views.LabelParams
function Label:new(params)
	View.new(self)
	local font_name = assert(params.font_name, "Label font_name is required")
	local font_size = assert(params.font_size, "Label font_size is required")
	self.font = Resources.getFont(font_name, font_size)
	self.text = params.text or ""
	self.color = params.color or Colors.text
	self.align = params.align or "left"
	self:updateSize()
end

function Label:updateSize()
	local width, lines = self.font:getWrap(self.text, math.huge)
	self:setSize(width, math.max(#lines, 1) * self.font:getHeight())
end

---@return string text
function Label:getText()
	return self.text
end

---@param text string
function Label:setText(text)
	self.text = text
	self:updateSize()
end

function Label:draw()
	Painter.snapToPixel()
	Painter.setColorTable(self.color)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 0, 0, self.width, self.align)
end

return Label
