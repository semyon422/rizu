local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.BMFontLabelParams
---@field font_name ui.BMFontName
---@field font_size number
---@field text string?
---@field color gui.Color?
---@field align "left"|"center"|"right"?

---Renders a bitmap font at the requested size while exposing its scaled size to layout.
---@class ui.views.BMFontLabel : gui.View
---@operator call: ui.views.BMFontLabel
---@field font love.Font
---@field font_size number
---@field font_scale number
---@field text string
---@field color gui.Color
---@field align "left"|"center"|"right"
local BMFontLabel = View + {}

---@param params ui.views.BMFontLabelParams
function BMFontLabel:new(params)
	View.new(self)
	self.font = Resources.getBMFont(params.font_name)
	self.font_size = params.font_size
	self.font_scale = self.font_size / self.font:getHeight()
	self.text = params.text or ""
	self.color = params.color or Colors.text
	self.align = params.align or "left"
	self:updateSize()
end

function BMFontLabel:updateSize()
	local width, lines = self.font:getWrap(self.text, math.huge)
	self:setSize(width * self.font_scale, math.max(#lines, 1) * self.font:getHeight() * self.font_scale)
end

---@return string text
function BMFontLabel:getText()
	return self.text
end

---@param text string
function BMFontLabel:setText(text)
	self.text = text
	self:updateSize()
end

function BMFontLabel:draw()
	Painter.snapToPixel()
	Painter.setColorTable(self.color)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, 0, 0, math.huge, self.align, 0, self.font_scale, self.font_scale)
end

return BMFontLabel
