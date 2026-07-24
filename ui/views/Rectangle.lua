local View = require("gui.View")
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
	local color = self.color
	love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * self.effective_opacity)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
end

return Rectangle
