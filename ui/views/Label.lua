local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("ui.Painter")
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
	self:setSize(self.font:getWidth(self.text), self.font:getHeight())
end

---@return string text
function Label:getText()
	return self.text
end

---@param text string
function Label:setText(text)
	self.text = text
	self:setSize(self.font:getWidth(text), self.font:getHeight())
end

function Label:draw()
	Painter.snapToPixel()
	local color = self.color
	love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * self.effective_opacity)
	love.graphics.setFont(self.font)
	local x = 0
	if self.align == "center" then
		x = (self.width - self.font:getWidth(self.text)) / 2
	elseif self.align == "right" then
		x = self.width - self.font:getWidth(self.text)
	end
	love.graphics.print(self.text, x, 0)
end

return Label
