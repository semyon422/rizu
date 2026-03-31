local View = require("ui.View")
local Painter = require("yi.Painter")

---@class ui.PanelParams
---@field atlas love.Image
---@field pixel love.Quad
---@field color number[]?
---@field border_color number[]?
---@field bevel_size number?

---@class ui.Panel : ui.View
---@overload fun(params: ui.PanelParams): ui.Panel
---@field atlas love.Image
---@field pixel love.Quad
---@field color number[]?
---@field border_color number[]?
---@field border_width number
---@field bevel_size number
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

	lg.setColor(self.color)
	Painter.drawPolygon("fill", self.fill_polygon_points)

	if self.draw_border_width == 0 or not self.border_color then
		return
	end

	lg.setColor(self.border_color)
	lg.setLineWidth(self.draw_border_width)
	Painter.drawLine(self.border_line_points)
end

return Panel
