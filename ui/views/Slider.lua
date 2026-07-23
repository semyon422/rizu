local View = require("gui.View")

---@class ui.views.Slider : gui.View
---@operator call: ui.views.Slider
---@field value number
---@field min number
---@field max number
---@field on_change fun(value: number)?
local Slider = View + {}

---@param params {value: number?, min: number?, max: number?, width: number?, on_change: fun(value: number)?}?
function Slider:new(params)
	View.new(self)
	params = params or {}
	self.min = params.min or 0
	self.max = params.max or 1
	assert(self.max > self.min, "slider max must be greater than min")
	self.value = params.value or self.min
	assert(self.value >= self.min and self.value <= self.max, "slider value must be within its range")
	self.on_change = params.on_change

	self.width = params.width or 300
	self.height = 24
	self.offset_max = {self.width, self.height}
	self.handles_mouse_input = true
end

---@param screen_x number
---@param screen_y number
function Slider:setValueAt(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local knob_radius = self.height / 2
	local position = math.max(0, math.min(1, (local_x - knob_radius) / (self.width - knob_radius * 2)))
	local value = self.min + (self.max - self.min) * position
	if value == self.value then
		return
	end
	self.value = value
	if self.on_change then
		self.on_change(value)
	end
end

---@param e gui.MouseDownEvent
function Slider:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.DragStartEvent
function Slider:onDragStart(e)
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.DragEvent
function Slider:onDrag(e)
	self:setValueAt(e.x, e.y)
	return true
end

local lg = love.graphics

function Slider:draw()
	local knob_radius = self.height / 2
	local track_height = 6
	local track_y = (self.height - track_height) / 2
	local position = (self.value - self.min) / (self.max - self.min)
	local knob_x = knob_radius + (self.width - knob_radius * 2) * position

	lg.setColor(0.25, 0.25, 0.3)
	lg.rectangle("fill", knob_radius, track_y, self.width - knob_radius * 2, track_height)
	lg.setColor(0.9, 0.9, 0.95)
	lg.rectangle("fill", knob_radius, track_y, knob_x - knob_radius, track_height)
	lg.rectangle("fill", knob_x - knob_radius, 0, knob_radius * 2, self.height)
end

return Slider
