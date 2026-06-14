local lg = love.graphics

local Resources = require("yi.Resources")
local makeSdfShader = require("yi.SdfShader")

---@class yi.Painter
---@field font love.Font
---@field font_shader love.Shader
---@field font_base_size number
---@field font_size number
local Painter = {
	font_size = 16,
	font_scale = 1,
	font_thickness = 0.5,
	font_outline = 0.0,
	font_outline_color = {0, 0, 0, 1},
	sdf_shader_basic = nil,
	sdf_shader_outline = nil,
}

function Painter.init()
	Painter.font = Resources.getSdfFont()
	Painter.font_base_size = Resources.sdf_font_base_size
	Painter.font_scale = Painter.font_size / Painter.font_base_size
	Painter.font_shader = makeSdfShader()
	Painter.font_shader:send("u_thickness", Painter.font_thickness)
	Painter.font_shader:send("u_outline", Painter.font_outline)
	Painter.font_shader:send("u_outline_color", Painter.font_outline_color)
end

function Painter.snapToPixel()
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.translate(math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
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

---@param size number
function Painter.setFontSize(size)
	Painter.font_size = size
	Painter.font_scale = size / Painter.font_base_size
end

---@param thickness number
function Painter.setFontThickness(thickness)
	if Painter.font_thickness == thickness then
		return
	end
	Painter.font_thickness = thickness
	Painter.font_shader:send("u_thickness", thickness)
end

---@param outline number
function Painter.setFontOutline(outline)
	if Painter.font_outline == outline then
		return
	end
	Painter.font_outline = outline
	Painter.font_shader:send("u_outline", outline)
end

---@param t gui.Color
function Painter.setFontOutlineColor(t)
	if Painter.font_outline_color == t then
		return
	end
	Painter.font_outline_color = t
	Painter.font_shader:send("u_outline_color", t)
end

---@param size number
function Painter.getFontHeight(size)
	return Painter.font:getHeight() * (size / Painter.font_base_size)
end


---@param text string
---@param font_size number
---@return number
function Painter.getFontWidth(text, font_size)
	return Painter.font:getWidth(text) * (font_size / Painter.font_base_size)
end

function Painter.beginTextDrawing()
	love.graphics.setShader(Painter.font_shader)
	love.graphics.setFont(Painter.font)
end

function Painter.endTextDrawing()
	love.graphics.setShader()
end

---@param text string
---@param x number?
---@param y number?
function Painter.print(text, x, y)
	lg.print(text, x, y, 0, Painter.font_scale, Painter.font_scale)
end

---@param text string
---@param x number?
---@param y number?
---@param limit number
---@param align love.AlignMode
function Painter.printf(text, x, y, limit, align)
	lg.printf(text, x or 0, y or 0, limit / Painter.font_scale, align, 0, Painter.font_scale, Painter.font_scale)
end

return Painter
