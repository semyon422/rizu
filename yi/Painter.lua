local lg = love.graphics

---@class yi.Painter
local Painter = {
	atlas = nil,
	scale = 1,
	pixel_mode = false,
	flow = "none",
	flow_x = 0,
	flow_y = 0,
	flow_gap = 0,
}

---@param atlas love.Image
function Painter.setAtlas(atlas)
	Painter.atlas = atlas
end

---@param scale number?
function Painter.setScale(scale)
	Painter.scale = scale or 1
end

---@param enabled boolean
---@param gap number?
---@param x number?
---@param y number?
function Painter.column(enabled, gap, x, y)
	if enabled then
		Painter.flow = "column"
		Painter.flow_gap = gap or 0
		Painter.flow_x = x or 0
		Painter.flow_y = y or 0
	else
		Painter.flow = "none"
	end
end

---@param enabled boolean
---@param gap number?
---@param x number?
---@param y number?
function Painter.row(enabled, gap, x, y)
	if enabled then
		Painter.flow = "row"
		Painter.flow_gap = gap or 0
		Painter.flow_x = x or 0
		Painter.flow_y = y or 0
	else
		Painter.flow = "none"
	end
end

---@param x number?
---@param y number?
---@return number
---@return number
local function flow_xy(x, y)
	if Painter.flow ~= "column" and Painter.flow ~= "row" then
		return x or 0, y or 0
	end
	return Painter.flow_x + (x or 0), Painter.flow_y + (y or 0)
end

---@param w number
---@param h number
local function flow_advance(w, h)
	if Painter.flow == "column" then
		Painter.flow_y = Painter.flow_y + h + Painter.flow_gap
	elseif Painter.flow == "row" then
		Painter.flow_x = Painter.flow_x + w + Painter.flow_gap
	end
end

---@param quad love.Quad
---@param x number?
---@param y number?
---@param width number?
---@param height number?
---@param r number?
function Painter.drawSprite(quad, x, y, width, height, r)
	x, y = flow_xy(x, y)
	local _, _, quad_w, quad_h = quad:getViewport()
	width = width or quad_w
	height = height or quad_h
	local out = lg.draw(Painter.atlas, quad, x, y, r, width / quad_w, height / quad_h)
	flow_advance(width, height)
	return out
end

function Painter.snapToPixel()
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.translate(math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
end

---@param drawable love.Drawable | love.Image
---@param x number?
---@param y number?
---@param r number?
function Painter.drawText(drawable, x, y, r)
	x, y = flow_xy(x, y)
	local ui_scale = Painter.scale or 1
	local draw_r = r
	local out

	lg.push()
	lg.translate(x, y)
	if ui_scale ~= 1 then
		lg.scale(1 / ui_scale)
	end
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.translate(math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
	out = lg.draw(drawable, 0, 0, draw_r)
	lg.pop()

	local w = drawable:getWidth()
	local h = drawable:getHeight()
	flow_advance((w / ui_scale), (h / ui_scale))
	return out
end

---@param x number
---@param y number
---@param width number
---@param height number
---@return integer
---@return integer
---@return integer
---@return integer
local function getSnappedScreenRect(x, y, width, height)
	local x1, y1 = lg.transformPoint(x, y)
	local x2, y2 = lg.transformPoint(x + width, y + height)
	local left = math.floor(math.min(x1, x2) + 0.5)
	local top = math.floor(math.min(y1, y2) + 0.5)
	local right = math.floor(math.max(x1, x2) + 0.5)
	local bottom = math.floor(math.max(y1, y2) + 0.5)
	return left, top, math.max(0, right - left), math.max(0, bottom - top)
end

---@param value number
---@return integer
function Painter.toPixelSize(value)
	return math.max(0, math.floor(value * (Painter.scale or 1) + 0.5))
end

---@param enabled boolean
---@param x number?
---@param y number?
function Painter.setPixelMode(enabled, x, y)
	if enabled then
		x, y = flow_xy(x, y)
		local screen_x, screen_y = lg.transformPoint(x or 0, y or 0)
		lg.push()
		lg.origin()
		lg.translate(math.floor(screen_x + 0.5), math.floor(screen_y + 0.5))
		Painter.pixel_mode = true
		return
	end

	if Painter.pixel_mode then
		Painter.pixel_mode = false
		lg.pop()
	end
end

---@param x number
---@param y number
---@param width number
---@param height number
function Painter.drawPixelRect(x, y, width, height)
	local left, top, rect_width, rect_height = getSnappedScreenRect(x, y, width, height)
	lg.push()
	lg.origin()
	lg.rectangle("fill", left, top, rect_width, rect_height)
	lg.pop()
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param line_width number
function Painter.drawPixelOutlineRect(x, y, width, height, line_width)
	local left, top, rect_width, rect_height = getSnappedScreenRect(x, y, width, height)
	local _, _, screen_line_width = getSnappedScreenRect(0, 0, line_width, 0)
	screen_line_width = math.max(1, screen_line_width)

	lg.push()
	lg.origin()
	lg.rectangle("fill", left, top, rect_width, screen_line_width)
	lg.rectangle("fill", left, top + rect_height - screen_line_width, rect_width, screen_line_width)
	lg.rectangle("fill", left, top, screen_line_width, rect_height)
	lg.rectangle("fill", left + rect_width - screen_line_width, top, screen_line_width, rect_height)
	lg.pop()
end

Painter.draw = lg.draw
Painter.drawLine = lg.line
Painter.drawPolygon = lg.polygon
Painter.setColor = lg.setColor
Painter.setBlendMode = lg.setBlendMode
Painter.push = lg.push
Painter.pop = lg.pop
Painter.translate = lg.translate
Painter.origin = lg.origin

return Painter
