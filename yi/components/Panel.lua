local View = require("ui.View")
local Painter = require("yi.Painter")

local crt_shader_code = [[
	extern float time;
	extern float strength;
	extern vec4 panel_rect;

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec4 tex = color;
		vec2 local = clamp((screen_coords - panel_rect.xy) / max(panel_rect.zw, vec2(1.0)), vec2(0.0), vec2(1.0));
		float edge_distance = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
		float edge = 1.0 - smoothstep(0.0, 0.22, edge_distance);
		float center = 1.0 - distance(local, vec2(0.5)) * 1.35;
		float scanline_phase = screen_coords.y * 1.45 + time * 15.0;
		float scanline = 1.0 - strength * 0.05 + sin(scanline_phase) * strength * 0.03;
		float grille = 1.0 - strength * 0.02 + sin(screen_coords.x * 2.4) * strength * 0.015;
		float flicker = 1.0 + sin(time * 43.0) * strength * 0.006;
		float band = sin(local.y * 18.0 - time * 1.1) * 0.5 + 0.5;
		float band_mask = smoothstep(0.45, 0.92, band) * 0.045 * strength;
		float panel_ratio = panel_rect.z / max(panel_rect.w, 1.0);

		tex.rgb = mix(tex.rgb, tex.rgb + vec3(0.035, 0.095, 0.13), edge * 0.9 * strength);
		tex.rgb += vec3(0.014, 0.04, 0.06) * band_mask * (0.7 + 0.3 * panel_ratio);
		tex.rgb *= 0.985 + center * 0.015;

		tex.rgb *= scanline * grille * flicker;
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
	self.crt_strength = params.crt_strength or 2
	self.fill_polygon_points = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.border_line_points = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.draw_border_width = 0
end

function Panel:load()
	self:build()
end

function Panel:build()
	local w, h = self.box.width, self.box.height
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
	local x1, y1 = lg.transformPoint(0, 0)
	local x2, y2 = lg.transformPoint(self.box.width, self.box.height)
	local left = math.min(x1, x2)
	local top = math.min(y1, y2)
	local width = math.max(1, math.abs(x2 - x1))
	local height = math.max(1, math.abs(y2 - y1))

	lg.push("all")
	shader:send("time", love.timer.getTime())
	shader:send("strength", self.crt_strength)
	shader:send("panel_rect", {left, top, width, height})
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
