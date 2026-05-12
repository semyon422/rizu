local View = require("yi.views.View")
local Colors = require("yi.Colors")
local math_util = require("math_util")

---@class yi.Slider : yi.View
---@overload fun(value: number, min: number, max: number, step: number?, on_change: fun(value: number)): yi.Slider
local Slider = View + {}

---@param value number
---@param min number
---@param max number
---@param step number?
---@param on_change fun(value: number)
function Slider:new(value, min, max, step, on_change)
	View.new(self)
	self:setup({
		w = 200,
		h = 32,
		mouse = true,
	})

	self.value = value or 0
	self.min = min or 0
	self.max = max or 1
	self.step = step
	self.on_change = on_change
	self.hovered = false
	self.dragging = false
end

function Slider:updateValueFromMouse(gx, gy)
	local lx, _ = self.transform:inverseTransformPoint(gx, gy)
	local w = self:getCalculatedWidth()
	local percent = math.max(0, math.min(1, lx / w))
	local new_value = self.min + (self.max - self.min) * percent

	if self.step then
		new_value = math_util.round(new_value, self.step)
	end

	new_value = math_util.clamp(new_value, self.min, self.max)

	if new_value ~= self.value then
		self.value = new_value
		if self.on_change then
			self.on_change(self.value)
		end
	end
end

function Slider:onHover()
	self.hovered = true
end

function Slider:onHoverLost()
	self.hovered = false
end

function Slider:onMouseDown(e)
	self.dragging = true
	self:updateValueFromMouse(e.x, e.y)
end

function Slider:onMouseUp()
	self.dragging = false
end

function Slider:onDrag(e)
	if self.dragging then
		self:updateValueFromMouse(e.x, e.y)
	end
end

function Slider:onDragEnd()
	self.dragging = false
end

function Slider:draw()
	local w, h = self:getCalculatedWidth(), self:getCalculatedHeight()

	local track_h = 4
	local track_y = h - 8

	love.graphics.setColor(Colors.panels)
	love.graphics.setLineWidth(track_h)
	love.graphics.line(0, track_y, w, track_y)

	local percent = (self.value - self.min) / (self.max - self.min)
	local fill_w = w * percent
	if fill_w > 0 then
		love.graphics.setColor(Colors.accent)
		love.graphics.line(0, track_y, fill_w, track_y)
	end

	local handle_h = 16
	local handle_x = fill_w

	if self.dragging then
		love.graphics.setColor(1, 1, 1, 1)
	elseif self.hovered then
		love.graphics.setColor(0.7, 0.7, 1, 1)
	else
		love.graphics.setColor(Colors.text)
	end

	love.graphics.setLineWidth(2)
	love.graphics.line(handle_x, track_y - handle_h / 2, handle_x, track_y + handle_h / 2)

	love.graphics.setColor(Colors.text)
	local display_val = self.step and self.value or math_util.round(self.value, 0.01)
	local text = tostring(display_val)
	local font = love.graphics.getFont()
	local tw = font:getWidth(text)
	local th = font:getHeight()

	local text_x = math.max(0, math.min(w - tw, handle_x - tw / 2))
	love.graphics.print(text, text_x, track_y - handle_h / 2 - th - 2)
end

return Slider
