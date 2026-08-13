local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.modals.input.BindingColumn : gui.View
---@operator call: ui.modals.input.BindingColumn
---@field column chart.Column
---@field binder rizu.InputBinder
---@field waiting boolean
---@field on_waiting fun(column: ui.modals.input.BindingColumn)
---@field on_changed fun()
local BindingColumn = View + {}

local LABEL_HEIGHT = 34

---@param column chart.Column
---@param binder rizu.InputBinder
---@param width number
---@param on_waiting fun(column: ui.modals.input.BindingColumn)
---@param on_changed fun()
function BindingColumn:new(column, binder, width, on_waiting, on_changed)
	View.new(self)
	self.column = column
	self.binder = binder
	self.on_waiting = on_waiting
	self.on_changed = on_changed
	self.waiting = false
	self.font = Resources.getFont("bold", 20)
	self.key_font = Resources.getFont("regular", 18)
	self.handles_mouse_input = true
	self:setSize(width, 118)
end

---@return string
function BindingColumn:getColumnLabel()
	local input_type, index = self.column:match("^(.-)(%d+)$")
	local postfix = input_type == "scratch" and "S" or "K"
	return tostring(index) .. postfix
end

---@param waiting boolean
function BindingColumn:setWaiting(waiting)
	self.waiting = waiting
end

---@param e gui.MouseClickEvent
function BindingColumn:onMouseClick(e)
	if e.button == 1 then
		self.on_waiting(self)
		return true
	elseif e.button == 2 then
		self:setWaiting(false)
		self.binder:setKey(self.column, 1)
		self.on_changed()
		return true
	end
end

function BindingColumn:draw()
	local lg = love.graphics
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text_muted)
	lg.setFont(self.font)
	lg.printf(self:getColumnLabel(), 0, 0, self.width, "center")

	if self.waiting then
		Painter.setColorTable(Colors.accent)
	elseif self.mouse_over then
		Painter.setColorTable(Colors.text)
	else
		Painter.setColorTable(Colors.outline)
	end
	lg.setLineWidth(2)
	lg.rectangle("line", 1, LABEL_HEIGHT + 1, self.width - 2, self.height - LABEL_HEIGHT - 2, 5, 5)

	local key = self.binder:getKey(self.column, 1)
	local text = self.waiting and "..." or (key and tostring(key):upper() or "")
	Painter.setColorTable(Colors.text)
	lg.setFont(self.key_font)
	lg.printf(text, 4, LABEL_HEIGHT + (self.height - LABEL_HEIGHT - self.key_font:getHeight()) / 2,
		self.width - 8, "center")
end

return BindingColumn
