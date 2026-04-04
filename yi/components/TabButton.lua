local View = require("ui.View")
local Colors = require("yi.Colors")
local Color = require("yi.Color")
local Painter = require("yi.Painter")
local TweenValue = require("ui.anim.TweenValue")

---@class yi.TabButtonParams
---@field pixel love.Quad
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field line_width number
---@field bevel_size number
---@field text_padding_x number
---@field active boolean
---@field on_click fun(button: yi.TabButton)?

---@class yi.TabButton : ui.View
---@overload fun(params: yi.TabButtonParams): yi.TabButton
---@field pixel love.Quad
---@field font love.Font
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field line_width number
---@field bevel_size number
---@field text_padding_x number
---@field active boolean
---@field on_click fun(button: yi.TabButton)?
---@field text_batch love.Text
local TabButton = View + {}

local hover_bg_color = {0, 0, 0, 1}
local bg_color = {0, 0, 0, 1}
local hover_text_color = {0, 0, 0, 1}
local text_color = {0, 0, 0, 1}
local outline_color = {0, 0, 0, 1}
local edge_color = {0, 0, 0, 1}

---@private
function TabButton:rebuildText()
	self.font = self.resources:getScaledFont(self.font_name, self.font_size, self.ui_scale)
	self.text_batch = love.graphics.newText(self.font, self.text)
end

---@param params yi.TabButtonParams
function TabButton:new(params)
	View.new(self)
	self.pixel = assert(params.pixel, "TabButton pixel quad is required")
	self.resources = assert(params.resources, "TabButton resources are required")
	self.font_name = assert(params.font_name, "TabButton font_name is required")
	self.font_size = assert(params.font_size, "TabButton font_size is required")
	self.text = assert(params.text, "TabButton text is required")
	self.line_width = assert(params.line_width, "TabButton line_width is required")
	self.bevel_size = assert(params.bevel_size, "TabButton bevel_size is required")
	self.text_padding_x = assert(params.text_padding_x, "TabButton text_padding_x is required")
	assert(params.active ~= nil, "TabButton active is required")
	self.active = params.active
	self.on_click = params.on_click
	self.fill_polygon_points = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.border_line_points = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.draw_line_width = self.line_width
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.is_focusable = true
	self.hover = TweenValue({
		easing = "outQuad",
		duration = 0.12,
	})
	self:rebuildText()
end

function TabButton:onResolutionChanged()
	self:rebuildText()
end

function TabButton:onGeometryChanged()
	local w = self.width
	local h = self.height
	local bevel = math.max(0, math.min(self.bevel_size, w, h))
	local fill_points = self.fill_polygon_points
	fill_points[1], fill_points[2] = 0, 0
	fill_points[3], fill_points[4] = w - bevel, 0
	fill_points[5], fill_points[6] = w, bevel
	fill_points[7], fill_points[8] = w, h
	fill_points[9], fill_points[10] = 0, h

	local points = self.border_line_points
	local border_width = self.line_width
	local half = border_width / 2
	local inner_bevel = math.max(0, math.min(bevel, w - half * 2, h - half * 2))
	points[1], points[2] = half, half
	points[3], points[4] = w - inner_bevel - half, half
	points[5], points[6] = w - half, inner_bevel + half
	points[7], points[8] = w - half, h - half
	points[9], points[10] = half, h - half
	points[11], points[12] = half, half
	self.draw_line_width = border_width
end

---@param active boolean
function TabButton:setActive(active)
	self.active = active
end

function TabButton:onHover()
	self.hover:set(1)
end

function TabButton:onHoverLost()
	self.hover:set(0)
end

---@param dt number
function TabButton:update(dt)
	self.hover:update(dt)
end

---@return boolean
function TabButton:click()
	if self.on_click then
		self.on_click(self)
		return true
	end
	return false
end

---@param e ui.KeyDownEvent
function TabButton:onKeyDown(e)
	if e.key == "return" then
		return self:click()
	end
end

---@param e ui.MouseClickEvent
function TabButton:onMouseClick(e)
	if e.button == 1 then
		return self:click()
	end
end

function TabButton:draw()
	local active = self.active
	local hovered = (self.mouse_over or self.focused) and (not active)
	local hover_t = self.hover:get()
	local base_bg_color = active and Colors.black_80 or Colors.slate_800_80
	Color.scale_to(hover_bg_color, base_bg_color, 1.1, 1.1)
	Color.mix_to(bg_color, base_bg_color, hover_bg_color, hover_t)

	local base_text_color = active and Colors.white or Colors.white_70
	Color.scale_to(hover_text_color, base_text_color, 1.05, 1.2)
	Color.mix_to(text_color, base_text_color, hover_text_color, hover_t)
	local _, th = self.text_batch:getDimensions()
	th = self:toLogicalSize(th)
	local text_x = self.text_padding_x
	local text_y = (self.height - th) / 2

	Painter.setColor(bg_color)
	Painter.drawPolygon("fill", self.fill_polygon_points)

	if active then
		outline_color[1], outline_color[2], outline_color[3], outline_color[4] =
			Colors.white_70[1], Colors.white_70[2], Colors.white_70[3], Colors.white_70[4]
	else
		Color.mix_to(outline_color, Colors.white_30, Colors.white_50, hover_t)
	end
	Painter.setColor(outline_color)
	love.graphics.setLineWidth(self.draw_line_width)
	Painter.drawLine(self.border_line_points)

	local edge_width = 0
	if active then
		edge_width = math.max(1, 6)
		Painter.setColor(Colors.cyan_400)
		Painter.drawSprite(self.pixel, 0, 0, edge_width, self.height)
	elseif hovered or hover_t > 0.001 then
		edge_width = math.max(1, 3 + hover_t * 2)
		Color.mix_to(edge_color, Colors.white_10, Colors.white_30, hover_t)
		Painter.setColor(edge_color)
		Painter.drawSprite(self.pixel, 0, 0, edge_width, self.height)
	end

	Painter.setColor(text_color)
	Painter.drawText(self.text_batch, text_x, text_y)
end

return TabButton
