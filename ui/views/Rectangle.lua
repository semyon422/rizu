local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.Rectangle : gui.View
---@operator call: ui.views.Rectangle
---@field color gui.Color
local Rectangle = View + {}

---@param color gui.Color
function Rectangle:new(color)
	View.new(self)
	self.color = color
end

function Rectangle:draw()
	Painter.setColorTable(self.color)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
end

return Rectangle
