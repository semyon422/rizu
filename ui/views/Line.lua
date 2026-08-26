local View = require("gui.View")
local Painter = require("gui.Painter")

local lg = love.graphics

---@class ui.views.Line.Config
---@field color gui.Color
---@field direction? "horizontal"|"vertical"
---@field thickness? number Render-target pixels.

---@class ui.views.Line : gui.View
---@operator call: ui.views.Line
---@field color gui.Color
---@field direction "horizontal"|"vertical"
---@field thickness number
local Line = View + {}

---@param config ui.views.Line.Config
function Line:new(config)
	View.new(self)
	self.color = config.color
	self.direction = config.direction or "horizontal"
	self.thickness = config.thickness or 1
	assert(self.direction == "horizontal" or self.direction == "vertical", "invalid line direction")
	assert(self.thickness > 0, "line thickness must be positive")
end

function Line:draw()
	local x1, y1 = lg.transformPoint(0, 0)
	local x2, y2
	if self.direction == "horizontal" then
		x2, y2 = lg.transformPoint(self.width, 0)
	else
		x2, y2 = lg.transformPoint(0, self.height)
	end

	Painter.setColorTable(self.color)
	lg.push("transform")
	lg.origin()
	if self.direction == "horizontal" then
		lg.rectangle("fill", math.min(x1, x2), math.floor(y1), math.abs(x2 - x1), self.thickness)
	else
		lg.rectangle("fill", math.floor(x1), math.min(y1, y2), self.thickness, math.abs(y2 - y1))
	end
	lg.pop()
end

return Line
