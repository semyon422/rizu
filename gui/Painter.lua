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
