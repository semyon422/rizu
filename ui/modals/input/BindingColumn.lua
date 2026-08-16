local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.modals.input.BindingColumn : gui.View
---@operator call: ui.modals.input.BindingColumn
---@field column chart.Column
---@field binder rizu.InputBinder
---@field waiting_index integer?
---@field on_waiting fun(column: ui.modals.input.BindingColumn, binding_index: integer)
---@field on_changed fun()
local BindingColumn = View + {}

local LABEL_HEIGHT = 34
local CELL_GAP = 2

---@param column chart.Column
---@param binder rizu.InputBinder
---@param width number
---@param on_waiting fun(column: ui.modals.input.BindingColumn, binding_index: integer)
---@param on_changed fun()
function BindingColumn:new(column, binder, width, on_waiting, on_changed)
	View.new(self)
	self.column = column
	self.binder = binder
	self.on_waiting = on_waiting
	self.on_changed = on_changed
	self.waiting_index = nil
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

---@return boolean
function BindingColumn:isScratch()
	return self.column:match("^scratch%d+$") ~= nil
end

---@return integer
function BindingColumn:getBindingCount()
	return self:isScratch() and 2 or 1
end

---@param waiting boolean
---@param binding_index integer?
function BindingColumn:setWaiting(waiting, binding_index)
	self.waiting_index = waiting and (binding_index or 1) or nil
end

---@param screen_x number
---@param screen_y number
---@return integer?
function BindingColumn:getBindingIndexAt(screen_x, screen_y)
	local _, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	if y < LABEL_HEIGHT or y > self.height then
		return
	end
	local binding_count = self:getBindingCount()
	local cell_height = (self.height - LABEL_HEIGHT - CELL_GAP * (binding_count - 1)) / binding_count
	local relative_y = y - LABEL_HEIGHT
	local binding_index = math.floor(relative_y / (cell_height + CELL_GAP)) + 1
	if binding_index > binding_count or relative_y - (binding_index - 1) * (cell_height + CELL_GAP) > cell_height then
		return
	end
	return binding_index
end

---@param e gui.MouseClickEvent
function BindingColumn:onMouseClick(e)
	local binding_index = self:getBindingIndexAt(e.x, e.y)
	if not binding_index then
		return
	end
	if e.button == 1 then
		self.on_waiting(self, binding_index)
		return true
	elseif e.button == 2 then
		self:setWaiting(false)
		self.binder:setKey(self.column, binding_index)
		self.on_changed()
		return true
	end
end

function BindingColumn:draw()
	local lg = love.graphics
	Painter.snapToPixel()
	local is_scratch = self:isScratch()
	Painter.setColorTable(is_scratch and Colors.accent2 or Colors.text_muted)
	lg.setFont(self.font)
	lg.printf(self:getColumnLabel(), 0, 0, self.width, "center")

	local binding_count = self:getBindingCount()
	local cell_height = (self.height - LABEL_HEIGHT - CELL_GAP * (binding_count - 1)) / binding_count
	local hovered_index ---@type integer?
	if self.mouse_over then
		hovered_index = self:getBindingIndexAt(love.mouse.getPosition())
	end

	lg.setLineWidth(2)
	lg.setFont(self.key_font)
	for binding_index = 1, binding_count do
		if self.waiting_index == binding_index then
			Painter.setColorTable(Colors.accent)
		elseif hovered_index == binding_index then
			Painter.setColorTable(Colors.text)
		else
			Painter.setColorTable(is_scratch and Colors.accent2 or Colors.outline)
		end
		local cell_y = LABEL_HEIGHT + (binding_index - 1) * (cell_height + CELL_GAP)
		lg.rectangle("line", 1, cell_y + 1, self.width - 2, cell_height - 2, 5, 5)

		local key = self.binder:getKey(self.column, binding_index)
		local text = self.waiting_index == binding_index and "..." or (key and tostring(key):upper() or "")
		Painter.setColorTable(is_scratch and Colors.accent2 or Colors.text)
		local text_width = self.key_font:getWidth(text)
		local available_width = self.width - 8
		local text_scale = text_width > available_width and available_width / text_width or 1
		lg.push()
		lg.translate(self.width / 2, cell_y + cell_height / 2)
		lg.scale(text_scale)
		lg.printf(text, -available_width / text_scale / 2, -self.key_font:getHeight() / 2,
			available_width / text_scale, "center")
		lg.pop()
	end
end

return BindingColumn
