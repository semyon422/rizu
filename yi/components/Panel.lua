local View = require("ui.View")
local Painter = require("yi.Painter")

local crt_shader_code = [[
	extern float time;
	extern float strength;

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec4 tex = color;

		float scanline_phase = screen_coords.y * 1.75 + time * 18.0;
		float scanline = 1.0 - strength * 0.1 + sin(scanline_phase) * strength * 0.085;
		float grille = 1.0 - strength * 0.06 + sin(screen_coords.x * 2.6) * strength * 0.035;
		float moving_pos = mod(time * 240.0, love_ScreenSize.y + 220.0) - 110.0;
		float beam = exp(-pow((screen_coords.y - moving_pos) / 48.0, 2.0)) * strength * 0.09;
		float flicker = 1.0 + sin(time * 52.0) * strength * 0.015;

		tex.rgb *= scanline * grille * flicker;
		tex.rgb += beam;

		return tex;
	}
]]

local crt_shader

---@return love.Shader
local function getCRTShader()
	crt_shader = crt_shader or love.graphics.newShader(crt_shader_code)
	return crt_shader
end

---@class ui.PanelParams
---@field atlas love.Image
---@field pixel love.Quad
---@field color number[]?
---@field border_color number[]?
---@field bevel_size number?
---@field crt_strength number?

---@class ui.Panel : ui.View
---@overload fun(params: ui.PanelParams): ui.Panel
---@field atlas love.Image
---@field pixel love.Quad
---@field color number[]?
---@field border_color number[]?
---@field border_width number
---@field bevel_size number
---@field crt_strength number
local Panel = View + {}

---@param params ui.PanelParams
function Panel:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Panel atlas is required")
	self.pixel = assert(params.pixel, "Panel pixel quad is required")
	self.color = params.color or {1, 1, 1, 1}
	self.border_color = params.border_color
	self.border_width = 2
	self.bevel_size = params.bevel_size or 18
	self.crt_strength = params.crt_strength or 1.6
	self.fill_polygon_points = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.border_line_points = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.draw_border_width = 0
end

function Panel:onGeometryChanged()
	local w, h = self.width, self.height
	local bevel = math.max(0, math.min(self.bevel_size, w, h))
	local fill_points = self.fill_polygon_points
	fill_points[1], fill_points[2] = bevel, 0
	fill_points[3], fill_points[4] = w, 0
	fill_points[5], fill_points[6] = w, h - bevel
	fill_points[7], fill_points[8] = w - bevel, h
	fill_points[9], fill_points[10] = 0, h
	fill_points[11], fill_points[12] = 0, bevel

	local border_width = math.max(0, math.min(self.border_width, w / 2, h / 2))
	local half = border_width / 2
	local points = self.border_line_points
	local inner_bevel = math.max(0, math.min(bevel, w - half * 2, h - half * 2))
	points[1], points[2] = inner_bevel + half, half
	points[3], points[4] = w - half, half
	points[5], points[6] = w - half, h - inner_bevel - half
	points[7], points[8] = w - inner_bevel - half, h - half
	points[9], points[10] = half, h - half
	points[11], points[12] = half, inner_bevel + half
	points[13], points[14] = inner_bevel + half, half
	self.draw_border_width = border_width
end

function Panel:draw()
	local lg = love.graphics
	local shader = getCRTShader()

	lg.push("all")
	shader:send("time", love.timer.getTime())
	shader:send("strength", self.crt_strength)
	lg.setShader(shader)
	lg.setColor(self.color)
	Painter.drawPolygon("fill", self.fill_polygon_points)
	lg.setShader()

	if self.draw_border_width == 0 or not self.border_color then
		lg.pop()
		return
	end

	lg.setColor(self.border_color)
	lg.setLineWidth(self.draw_border_width)
	Painter.drawLine(self.border_line_points)
	lg.pop()
end

return Panel
