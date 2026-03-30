local View = require("ui.View")

---@class ui.PanelParams
---@field atlas love.Image
---@field rect_corner love.Quad
---@field rect_corner_border love.Quad?
---@field pixel love.Quad
---@field corners boolean[]?
---@field color number[]?
---@field border_color number[]?

---@class ui.Panel : ui.View
---@overload fun(params: ui.PanelParams): ui.Panel
---@field atlas love.Image
---@field rect_corner love.Quad
---@field rect_corner_border love.Quad?
---@field pixel love.Quad
---@field corners boolean[]?
---@field color number[]?
---@field border_color number[]?
---@field border_width number
local Panel = View + {}

---@param params ui.PanelParams
function Panel:new(params)
	View.new(self)
	self.atlas = assert(params.atlas, "Panel atlas is required")
	self.rect_corner = assert(params.rect_corner, "Panel rect_corner quad is required")
	self.rect_corner_border = params.rect_corner_border
	self.pixel = assert(params.pixel, "Panel pixel quad is required")
	self.corners = params.corners
	self.color = params.color or {1, 1, 1, 1}
	self.border_color = params.border_color
	self.border_width = 2
end

function Panel:draw()
	local atlas = self.atlas
	local rect_corner = self.rect_corner
	local rect_corner_border = self.rect_corner_border
	local pixel = self.pixel
	local _, _, corner_w, corner_h = rect_corner:getViewport()
	local w, h = self.width, self.height
	local draw_corner_w = math.min(corner_w, w / 2)
	local draw_corner_h = math.min(corner_h, h / 2)
	local inner_w = math.max(0, w - draw_corner_w * 2)
	local inner_h = math.max(0, h - draw_corner_h * 2)
	local corner_sx = draw_corner_w / corner_w
	local corner_sy = draw_corner_h / corner_h
	local corners = self.corners or {}
	local top_left = corners[1] ~= false
	local top_right = corners[2] ~= false
	local bottom_right = corners[3] ~= false
	local bottom_left = corners[4] ~= false
	local lg = love.graphics

	lg.setColor(self.color)
	if top_left then
		lg.draw(atlas, rect_corner, 0, 0, 0, corner_sx, corner_sy)
	else
		lg.draw(atlas, pixel, 0, 0, 0, draw_corner_w, draw_corner_h)
	end
	if top_right then
		lg.draw(atlas, rect_corner, w, 0, 0, -corner_sx, corner_sy)
	else
		lg.draw(atlas, pixel, w - draw_corner_w, 0, 0, draw_corner_w, draw_corner_h)
	end
	if bottom_right then
		lg.draw(atlas, rect_corner, w, h, 0, -corner_sx, -corner_sy)
	else
		lg.draw(atlas, pixel, w - draw_corner_w, h - draw_corner_h, 0, draw_corner_w, draw_corner_h)
	end
	if bottom_left then
		lg.draw(atlas, rect_corner, 0, h, 0, corner_sx, -corner_sy)
	else
		lg.draw(atlas, pixel, 0, h - draw_corner_h, 0, draw_corner_w, draw_corner_h)
	end

	lg.draw(atlas, pixel, draw_corner_w, 0, 0, inner_w, draw_corner_h)
	lg.draw(atlas, pixel, draw_corner_w, h - draw_corner_h, 0, inner_w, draw_corner_h)
	lg.draw(atlas, pixel, 0, draw_corner_h, 0, draw_corner_w, inner_h)
	lg.draw(atlas, pixel, w - draw_corner_w, draw_corner_h, 0, draw_corner_w, inner_h)
	lg.draw(atlas, pixel, draw_corner_w, draw_corner_h, 0, inner_w, inner_h)

	local border_width = math.max(0, math.min(self.border_width, w / 2, h / 2))
	if border_width == 0 or not self.border_color then
		return
	end

	local border_w = math.min(border_width, draw_corner_w)
	local border_h = math.min(border_width, draw_corner_h)
	local top_x = top_left and draw_corner_w or 0
	local top_w = math.max(0, w - (top_left and draw_corner_w or 0) - (top_right and draw_corner_w or 0))
	local bottom_x = bottom_left and draw_corner_w or 0
	local bottom_w = math.max(0, w - (bottom_left and draw_corner_w or 0) - (bottom_right and draw_corner_w or 0))
	local left_y = top_left and draw_corner_h or 0
	local left_h = math.max(0, h - (top_left and draw_corner_h or 0) - (bottom_left and draw_corner_h or 0))
	local right_y = top_right and draw_corner_h or 0
	local right_h = math.max(0, h - (top_right and draw_corner_h or 0) - (bottom_right and draw_corner_h or 0))

	lg.setColor(self.border_color)
	if rect_corner_border then
		if top_left then
			lg.draw(atlas, rect_corner_border, 0, 0, 0, corner_sx, corner_sy)
		end
		if top_right then
			lg.draw(atlas, rect_corner_border, w, 0, 0, -corner_sx, corner_sy)
		end
		if bottom_right then
			lg.draw(atlas, rect_corner_border, w, h, 0, -corner_sx, -corner_sy)
		end
		if bottom_left then
			lg.draw(atlas, rect_corner_border, 0, h, 0, corner_sx, -corner_sy)
		end
	end

	lg.draw(atlas, pixel, top_x, 0, 0, top_w, border_h)
	lg.draw(atlas, pixel, bottom_x, h - border_h, 0, bottom_w, border_h)
	lg.draw(atlas, pixel, 0, left_y, 0, border_w, left_h)
	lg.draw(atlas, pixel, w - border_w, right_y, 0, border_w, right_h)
end

return Panel
