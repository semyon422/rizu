local FormControl = require("ui.views.form.FormControl")
local FormNavigation = require("ui.views.form.FormNavigation")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.modals.column_order.ColumnGrid.Params
---@field label string
---@field hint fun(column: integer): string Replaces the label while a column is picked.
---@field order integer[] Which chart column each key plays.
---@field on_change fun(order: integer[])
---@field width number

---Keys in rows of equal length, each showing the chart column it plays. Pick one, then another to swap them.
---With the keyboard, Enter picks a column up and the arrows carry it along.
---@class ui.modals.column_order.ColumnGrid : ui.views.form.FormControl
---@operator call: ui.modals.column_order.ColumnGrid
---@field order integer[]
---@field picked integer? Index of the key whose column is picked up.
---@field cursor integer
---@field per_row integer
---@field grid_width number
local ColumnGrid = FormControl + {}

local BODY_Y = 25
local CELL_SIZE = 48
local GAP = 8

---@param params ui.modals.column_order.ColumnGrid.Params
function ColumnGrid:new(params)
	FormControl.new(self)
	self.label_text = params.label
	self.hint = params.hint
	self.on_change = params.on_change
	self.picked = nil
	self.cursor = 1
	self.font = Resources.getFont("medium", 18)
	self.background_left = Resources.sprites.segmented_bg_left
	self.background_middle = Resources.sprites.segmented_bg_middle
	self.background_right = Resources.sprites.segmented_bg_right
	self.grid_width = params.width
	self:setWidth(params.width)
	self:setOrder(params.order)
	self.handles_mouse_input = true
end

---@param order integer[]
function ColumnGrid:setOrder(order)
	self.order = order
	self.picked = nil
	self.cursor = math.max(1, math.min(self.cursor, #order))
	local max_per_row = math.max(1, math.floor((self.grid_width + GAP) / (CELL_SIZE + GAP)))
	local rows = math.max(1, math.ceil(#order / max_per_row))
	self.per_row = math.ceil(#order / rows)
	self:setHeight(BODY_Y + rows * (CELL_SIZE + GAP) - GAP)
end

---@param text string
function ColumnGrid:setLabel(text)
	self.label_text = text
end

---@param a integer
---@param b integer
function ColumnGrid:swap(a, b)
	local order = self.order
	order[a], order[b] = order[b], order[a]
	self.on_change(order)
end

---Picks the column up, or drops it onto another key.
---@param index integer
function ColumnGrid:press(index)
	local picked = self.picked
	self.picked = nil
	if not picked then
		self.picked = index
	elseif picked ~= index then
		self:swap(picked, index)
	end
end

---@param e gui.KeyDownEvent?
---@return boolean activated
function ColumnGrid:activate(e)
	self:press(self.cursor)
	return true
end

---@param e gui.KeyDownEvent
---@return boolean handled
function ColumnGrid:onFormKeyDown(e)
	local direction = e.key == "left" and -1 or e.key == "right" and 1 or nil
	if not direction then
		return false
	end
	local target = math.max(1, math.min(self.cursor + direction, #self.order))
	if self.picked and target ~= self.picked then
		self:swap(self.picked, target)
		self.picked = target
	end
	self.cursor = target
	return true
end

---@param index integer
---@return number x
---@return number y
function ColumnGrid:getCellPosition(index)
	local row, column = math.floor((index - 1) / self.per_row), (index - 1) % self.per_row
	return column * (CELL_SIZE + GAP), BODY_Y + row * (CELL_SIZE + GAP)
end

---@param screen_x number
---@param screen_y number
---@return integer? index
function ColumnGrid:getIndexAt(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	for index = 1, #self.order do
		local cell_x, cell_y = self:getCellPosition(index)
		if x >= cell_x and x <= cell_x + CELL_SIZE and y >= cell_y and y <= cell_y + CELL_SIZE then
			return index
		end
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function ColumnGrid:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if index then
		self.cursor = index
		self:press(index)
	else
		self.picked = nil
	end
	return true
end

---@return boolean
function ColumnGrid:isKeyboardSelected()
	local form = self.parent and self.parent.parent
	---@cast form ui.views.form.Form?
	return form ~= nil and form.selected_control == self and form.navigation == FormNavigation.Keyboard
end

function ColumnGrid:draw()
	local hovered ---@type integer?
	local inputs = self.screen and self.screen.inputs
	if self.mouse_over and inputs then
		hovered = self:getIndexAt(inputs.mouse_x, inputs.mouse_y)
	end
	local cursor = self:isKeyboardSelected() and self.cursor or nil

	local left_width = self.background_left:getWidth()
	local right_width = self.background_right:getWidth()
	local scale_y = CELL_SIZE / self.background_left:getHeight()
	local middle_scale_x = (CELL_SIZE - left_width - right_width) / self.background_middle:getWidth()
	for index = 1, #self.order do
		local x, y = self:getCellPosition(index)
		if index == self.picked then
			Painter.setColorTable(Colors.accent)
		elseif index == hovered or index == cursor then
			Painter.setColorTable(Colors.surface_raised)
		else
			Painter.setColorTable(Colors.surface)
		end
		self.background_left:draw(x, y, 0, 1, scale_y)
		self.background_middle:draw(x + left_width, y, 0, middle_scale_x, scale_y)
		self.background_right:draw(x + CELL_SIZE - right_width, y, 0, 1, scale_y)
	end

	Painter.snapToPixel()
	love.graphics.setFont(self.font)
	Painter.setColorTable(Colors.text)
	love.graphics.print(self.picked and self.hint(self.order[self.picked]) or self.label_text, 0, 0)

	local text_offset = (CELL_SIZE - self.font:getHeight()) / 2
	for index, column in ipairs(self.order) do
		local x, y = self:getCellPosition(index)
		if index == self.picked then
			Painter.setColorTable(Colors.panel)
		elseif column ~= index then
			Painter.setColorTable(Colors.accent) -- moved from its own key
		else
			Painter.setColorTable(Colors.text)
		end
		love.graphics.printf(tostring(column), x, y + text_offset, CELL_SIZE, "center")
	end
end

return ColumnGrid
