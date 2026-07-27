local Painter = require("gui.Painter")
local View = require("gui.View")

---@class ui.views.Slider : gui.View
---@operator call: ui.views.Slider
---@field value number
---@field min number
---@field max number
---@field step number?
---@field on_change fun(value: number)?
local Slider = View + {}

---@param params {value: number?, min: number?, max: number?, step: number?, width: number?, on_change: fun(value: number)?}?
function Slider:new(params)
	View.new(self)
	params = params or {}
	self.min = params.min or 0
	self.max = params.max or 1
	assert(self.max > self.min, "slider max must be greater than min")
	self.value = params.value or self.min
	assert(self.value >= self.min and self.value <= self.max, "slider value must be within its range")
	self.step = params.step
	assert(not self.step or self.step > 0, "slider step must be positive")
	self.on_change = params.on_change

	self:setSize(params.width or 300, 24)
	self.handles_mouse_input = true
	self.drag_axis = "horizontal"
end

---@param screen_x number
---@param screen_y number
function Slider:setValueAt(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local knob_radius = self.height / 2
	local position = math.max(0, math.min(1, (local_x - knob_radius) / (self.width - knob_radius * 2)))
	local value = self.min + (self.max - self.min) * position
	if self.step then
		value = self.min + math.floor((value - self.min) / self.step + 0.5) * self.step
		value = math.max(self.min, math.min(self.max, value))
	end
	self:setValue(value, true)
end

---@param value number
---@param notify boolean?
function Slider:setValue(value, notify)
	assert(value >= self.min and value <= self.max, "slider value must be within its range")
	if value == self.value then
		return
	end
	self.value = value
	if notify and self.on_change then
		self.on_change(value)
	end
end

---@param e gui.MouseDownEvent
function Slider:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	return true
end

---@param e gui.DragStartEvent
function Slider:onDragStart(e)
	if e.button ~= 1 then
		return
	end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.DragEvent
function Slider:onDrag(e)
	if e.button ~= 1 then
		return
	end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function Slider:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
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

	Painter.setColorRgb(0.25, 0.25, 0.3)
	lg.rectangle("fill", knob_radius, track_y, self.width - knob_radius * 2, track_height)
	Painter.setColorRgb(0.9, 0.9, 0.95)
	lg.rectangle("fill", knob_radius, track_y, knob_x - knob_radius, track_height)
	lg.rectangle("fill", knob_x - knob_radius, 0, knob_radius * 2, self.height)
end

return Slider
