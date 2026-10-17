local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

local lg = love.graphics

---@class ui.views.Panel.Lines
---@field top? boolean
---@field right? boolean
---@field bottom? boolean
---@field left? boolean

---@class ui.views.Panel.Config
---@field color gui.Color
---@field line_color? gui.Color
---@field line_width? number Render-target pixels.
---@field lines? ui.views.Panel.Lines Defaults to all edges when line_color is set.

---@class ui.views.Panel : gui.View
---@operator call: ui.views.Panel
---@field color gui.Color
---@field line_color gui.Color?
---@field line_width number
---@field lines ui.views.Panel.Lines
local Panel = View + {}

---@param config ui.views.Panel.Config
function Panel:new(config)
	View.new(self)
	self.color = config.color
	self.line_color = config.line_color
	self.line_width = config.line_width or 1
	self.lines = config.lines or {top = true, right = true, bottom = true, left = true}
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
local function drawFixedLine(x1, y1, x2, y2)
	x1, y1 = lg.transformPoint(x1, y1)
	x2, y2 = lg.transformPoint(x2, y2)
	lg.push("transform")
	lg.origin()
	lg.line(x1, y1, x2, y2)
	lg.pop()
end

function Panel:draw()
	Painter.setColorTable(self.color)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)

	if not self.line_color then
		return
	end

	Painter.setColorTable(self.line_color)
	local previous_line_width = lg.getLineWidth()
	lg.setLineWidth(self.line_width)
	local lines = self.lines
	if lines.top then drawFixedLine(0, 0, self.width, 0) end
	if lines.right then drawFixedLine(self.width, 0, self.width, self.height) end
	if lines.bottom then drawFixedLine(0, self.height, self.width, self.height) end
	if lines.left then drawFixedLine(0, 0, 0, self.height) end
	lg.setLineWidth(previous_line_width)
end

return Panel
