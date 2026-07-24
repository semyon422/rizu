local lg = love.graphics

---@class yi.Painter
local Painter = {}

local opacity = 0

function Painter.init() end

function Painter.snapToPixel()
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.translate(math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
end

function Painter.setOpacity(a)
	opacity = a
end

function Painter.setColorRgb(r, g, b)
	love.graphics.setColor(r, g, b, opacity)
end

function Painter.setColorTable(t)
	love.graphics.setColor(t[1], t[2], t[3], opacity)
end

---@param quad love.Quad
---@return number
function Painter.getQuadWidth(quad)
	local _, _, w, _ = quad:getViewport()
	return w
end

---@param quad love.Quad
---@return number
function Painter.getQuadHeight(quad)
	local _, _, _, h = quad:getViewport()
	return h
end

return Painter
