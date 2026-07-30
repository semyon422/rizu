local FormControl = require("ui.views.form.FormControl")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.form.SliderParams
---@field label string
---@field value number?
---@field min number?
---@field max number?
---@field step number?
---@field width number?
---@field on_change fun(value: number)?

---@class ui.views.form.Slider : ui.views.form.FormControl
---@operator call: ui.views.form.Slider
---@field value number
---@field min number
---@field max number
---@field step number?
---@field label_text string
---@field font love.Font
---@field on_change fun(value: number)?
---@field line_left gui.Sprite
---@field line_middle gui.Sprite
---@field line_right gui.Sprite
---@field thumb gui.Sprite
local Slider = FormControl + {}

local HEIGHT = 46
local LINE_Y = 31
local THUMB_Y = 23

---@param params ui.views.form.SliderParams
function Slider:new(params)
	FormControl.new(self)
	self.min = params.min or 0
	self.max = params.max or 1
	assert(self.max > self.min, "slider max must be greater than min")
	self.value = params.value or self.min
	assert(self.value >= self.min and self.value <= self.max, "slider value must be within its range")
	self.step = params.step
	assert(not self.step or self.step > 0, "slider step must be positive")
	self.label_text = params.label
	self.font = Resources.getFont("medium", 16)
	self.on_change = params.on_change
	self.line_left = Resources.sprites.slider_line_left
	self.line_middle = Resources.sprites.slider_line_middle
	self.line_right = Resources.sprites.slider_line_right
	self.thumb = Resources.sprites.slider_thumb

	local width = params.width or 300
	assert(width >= self.thumb:getWidth(), "slider width is too small")
	self:setSize(width, HEIGHT)
	self.handles_mouse_input = true
	self.drag_axis = "horizontal"
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

---@param screen_x number
---@param screen_y number
function Slider:setValueAt(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local thumb_radius = self.thumb:getWidth() / 2
	local position = math.max(0, math.min(1, (local_x - thumb_radius) / (self.width - thumb_radius * 2)))
	local value = self.min + (self.max - self.min) * position
	if self.step then
		value = self.min + math.floor((value - self.min) / self.step + 0.5) * self.step
		value = math.max(self.min, math.min(self.max, value))
	end
	self:setValue(value, true)
end

---@param e gui.DragStartEvent
---@return boolean?
function Slider:onDragStart(e)
	if e.button ~= 1 then
		return
	end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.DragEvent
---@return boolean?
function Slider:onDrag(e)
	if e.button ~= 1 then
		return
	end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.MouseClickEvent
---@return boolean?
function Slider:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	self:setValueAt(e.x, e.y)
	return true
end

---@param self ui.views.form.Slider
---@param width number
local function drawLine(self, width)
	local left_width = self.line_left:getWidth()
	local right_width = self.line_right:getWidth()
	local middle_width = width - left_width - right_width
	self.line_left:draw(0, LINE_Y)
	self.line_middle:draw(left_width, LINE_Y, 0, middle_width / self.line_middle:getWidth(), 1)
	self.line_right:draw(width - right_width, LINE_Y)
end

function Slider:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.label_text, 0, 0)

	Painter.setColorTable(Colors.background)
	drawLine(self, self.width)

	local position = (self.value - self.min) / (self.max - self.min)
	local thumb_radius = self.thumb:getWidth() / 2
	local thumb_x = thumb_radius + (self.width - thumb_radius * 2) * position
	Painter.setColorTable(Colors.accent)
	drawLine(self, thumb_x)
	self.thumb:draw(thumb_x - thumb_radius, THUMB_Y)
end

return Slider
