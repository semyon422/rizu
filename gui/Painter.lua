local lg = love.graphics

---@class gui.Painter
local Painter = {}

local inherited_opacity = 1
local local_opacity = 1
local red, green, blue = 1, 1, 1
local color_opacity = 1

local function applyColor()
	lg.setColor(red, green, blue, inherited_opacity * local_opacity * color_opacity)
end

---@param opacity number
function Painter.begin(opacity)
	inherited_opacity = opacity
	local_opacity = 1
	red, green, blue = 1, 1, 1
	color_opacity = 1
	applyColor()
end

---@param opacity number
function Painter.setOpacity(opacity)
	local_opacity = opacity
	applyColor()
end

---@param r number
---@param g number
---@param b number
---@param a number?
function Painter.setColorRgb(r, g, b, a)
	red, green, blue = r, g, b
	color_opacity = a or 1
	applyColor()
end

---@param color gui.Color
function Painter.setColorTable(color)
	red, green, blue = color[1], color[2], color[3]
	color_opacity = color[4] or 1
	applyColor()
end

function Painter.snapToPixel()
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.translate(math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
end

---Draws a transformed rectangle outline with a render-target-space line width.
---The rectangle follows the active transform, but scaling does not affect its stroke.
---@param x number
---@param y number
---@param width number
---@param height number
---@param line_width number
function Painter.rectangleLineFixed(x, y, width, height, line_width)
	assert(type(x) == "number" and type(y) == "number", "rectangle position must be numeric")
	assert(type(width) == "number" and type(height) == "number", "rectangle size must be numeric")
	assert(type(line_width) == "number" and line_width > 0, "line width must be positive")

	local x1, y1 = lg.transformPoint(x, y)
	local x2, y2 = lg.transformPoint(x + width, y)
	local x3, y3 = lg.transformPoint(x + width, y + height)
	local x4, y4 = lg.transformPoint(x, y + height)
	local previous_line_width = lg.getLineWidth()

	lg.push("transform")
	lg.origin()
	lg.setLineWidth(line_width)
	lg.polygon("line", x1, y1, x2, y2, x3, y3, x4, y4)
	lg.pop()
	lg.setLineWidth(previous_line_width)
end

---@param quad love.Quad
---@return number
function Painter.getQuadWidth(quad)
	local _, _, width = quad:getViewport()
	return width
end

---@param quad love.Quad
---@return number
function Painter.getQuadHeight(quad)
	local _, _, _, height = quad:getViewport()
	return height
end

return Painter
