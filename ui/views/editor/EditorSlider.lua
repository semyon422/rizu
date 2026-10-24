local EditorRow = require("ui.views.editor.EditorRow")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")

---@class ui.views.editor.EditorSliderParams
---@field label string?
---@field value number
---@field min number
---@field max number
---@field step number?
---@field width number
---@field fill_color number[]? Color of the filled part, for color channels.
---@field value_format (fun(value: number): string)?
---@field on_change fun(value: number)?

---A field filled up to its value, with the value written over it. Click or drag to set it,
---or step it with the left and right keys while the mouse is over it.
---@class ui.views.editor.EditorSlider : ui.views.editor.EditorRow
---@operator call: ui.views.editor.EditorSlider
---@field value number
---@field min number
---@field max number
---@field step number?
---@field fill_color number[]?
---@field value_format fun(value: number): string
---@field on_change fun(value: number)?
local EditorSlider = EditorRow + {}

local FILL_ALPHA = 0.6 -- colored fills are loud at full strength

---@param params ui.views.editor.EditorSliderParams
function EditorSlider:new(params)
	EditorRow.new(self, params.label, params.width)
	self.min, self.max = params.min, params.max
	assert(self.max > self.min, "slider max must be greater than min")
	self.step = params.step
	assert(not self.step or self.step > 0, "slider step must be positive")
	self.value = math.max(self.min, math.min(self.max, params.value))
	self.fill_color = params.fill_color
	self.value_format = params.value_format or tostring
	self.on_change = params.on_change
	self.drag_axis = "horizontal"
	self.handles_keyboard_input = true
end

---@param value number
---@param notify boolean?
function EditorSlider:setValue(value, notify)
	if value == self.value then return end
	self.value = value
	if notify and self.on_change then self.on_change(value) end
end

---@param screen_x number
---@param screen_y number
function EditorSlider:setValueAt(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local x, width = self:getField()
	local position = math.max(0, math.min(1, (local_x - x) / width))
	local value = self.min + (self.max - self.min) * position
	if self.step then
		value = self.min + math.floor((value - self.min) / self.step + 0.5) * self.step
		value = math.max(self.min, math.min(self.max, value))
	end
	self:setValue(value, true)
end

---@param e gui.KeyDownEvent
---@return boolean handled
function EditorSlider:onKeyDown(e)
	local direction = e.key == "left" and -1 or e.key == "right" and 1 or nil
	if not self.mouse_over or not direction then return false end
	local step = self.step or (self.max - self.min) / 100
	self:setValue(math.max(self.min, math.min(self.max, self.value + step * direction)), true)
	return true
end

---@param e gui.DragStartEvent
---@return boolean?
function EditorSlider:onDragStart(e)
	if e.button ~= 1 then return end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.DragEvent
---@return boolean?
function EditorSlider:onDrag(e)
	if e.button ~= 1 then return end
	self:setValueAt(e.x, e.y)
	return true
end

---@param e gui.MouseClickEvent
---@return boolean?
function EditorSlider:onMouseClick(e)
	if e.button ~= 1 then return end
	self:setValueAt(e.x, e.y)
	return true
end

function EditorSlider:draw()
	Painter.snapToPixel()
	self:drawLabel()
	local x, width = self:getField()
	local height = self.height
	EditorRow.fillRect(Colors.surface, x, 0, width, height)

	local fill = self.fill_color
	local fill_color = fill and {fill[1], fill[2], fill[3], FILL_ALPHA} or Colors.outline
	local position = (self.value - self.min) / (self.max - self.min)
	EditorRow.fillRect(fill_color, x, 0, math.floor(width * position + 0.5), height)

	Painter.setColorTable(Colors.text)
	self:printText(self.value_format(self.value), x, width, "center")
	if self.mouse_over then
		Painter.setColorTable(Colors.accent)
		Painter.rectangleLineFixed(x, 0, width, height, 1)
	end
end

return EditorSlider
