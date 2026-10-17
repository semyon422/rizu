local ChartFormat = require("sea.chart.ChartFormat")
local Colors = require("ui.Colors")
local FormControl = require("ui.views.form.FormControl")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.views.form.FormatMultiSelectParams
---@field label string
---@field values? string[]
---@field on_change? fun(values: string[])

---@class ui.views.form.FormatMultiSelect : ui.views.form.FormControl
---@operator call: ui.views.form.FormatMultiSelect
---@field values string[]
local FormatMultiSelect = FormControl + {}

local WIDTH = 600
local ROW_Y = 25
local ROW_HEIGHT = 34
local ROW_GAP = 8
local GAP = 8

---@param params ui.views.form.FormatMultiSelectParams
function FormatMultiSelect:new(params)
	FormControl.new(self)
	self.label = params.label
	self.values = {}
	self.on_change = params.on_change
	self.font = Resources.getFont("medium", 16)
	self.background = NineSliceUsage(Resources.nine_slices.song_select_toolbar_control)
	self.handles_mouse_input = true
	self.formats = ChartFormat:list()
	self:setSize(WIDTH, self:getHeight())
	self:setValues(params.values or {})
end

---@return number
function FormatMultiSelect:getHeight()
	local x, rows = 0, 1
	for _, value in ipairs(self.formats) do
		local width = self.font:getWidth(value:upper()) + 28
		if x > 0 and x + width > WIDTH then
			x, rows = 0, rows + 1
		end
		x = x + width + GAP
	end
	return ROW_Y + rows * ROW_HEIGHT + (rows - 1) * ROW_GAP
end

---@param value string
---@return boolean
function FormatMultiSelect:isSelected(value)
	for _, selected in ipairs(self.values) do
		if selected == value then return true end
	end
	return false
end

---@param values string[]
---@param notify boolean?
function FormatMultiSelect:setValues(values, notify)
	local selected = {}
	for _, value in ipairs(values) do
		selected[value] = true
	end
	local normalized = {}
	for _, value in ipairs(self.formats) do
		if selected[value] then normalized[#normalized + 1] = value end
	end
	self.values = normalized
	if notify and self.on_change then self.on_change(self.values) end
end

---@param value string
function FormatMultiSelect:toggle(value)
	local values = {}
	local removed = false
	for _, selected in ipairs(self.values) do
		if selected == value then
			removed = true
		else
			values[#values + 1] = selected
		end
	end
	if not removed then values[#values + 1] = value end
	self:setValues(values, true)
end

---@param e gui.MouseClickEvent
---@return boolean?
function FormatMultiSelect:onMouseClick(e)
	if e.button ~= 1 then return end
	local x, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	local left, top = 0, ROW_Y
	for _, value in ipairs(self.formats) do
		local width = self.font:getWidth(value:upper()) + 28
		if left > 0 and left + width > self.width then
			left, top = 0, top + ROW_HEIGHT + ROW_GAP
		end
		if x >= left and x <= left + width and y >= top and y <= top + ROW_HEIGHT then
			self:toggle(value)
			Sounds.play("click")
			return true
		end
		left = left + width + GAP
	end
end

---@param text string
---@param x number
---@param y number
---@param selected boolean
function FormatMultiSelect:drawButton(text, x, y, selected)
	local width = self.font:getWidth(text) + 28
	Painter.setColorTable(selected and Colors.accent or Colors.surface)
	love.graphics.push("transform")
	love.graphics.translate(x, y)
	self.background:draw(width, ROW_HEIGHT)
	love.graphics.pop()
	Painter.setColorTable(selected and Colors.panel or Colors.text)
	love.graphics.printf(text, x, y + (ROW_HEIGHT - self.font:getHeight()) / 2, width, "center")
end

function FormatMultiSelect:draw()
	Painter.snapToPixel()
	love.graphics.setFont(self.font)
	Painter.setColorTable(Colors.text)
	love.graphics.print(self.label, 0, 0)

	local x, y = 0, ROW_Y
	for _, value in ipairs(self.formats) do
		local text = value:upper()
		local width = self.font:getWidth(text) + 28
		if x > 0 and x + width > self.width then
			x, y = 0, y + ROW_HEIGHT + ROW_GAP
		end
		self:drawButton(text, x, y, self:isSelected(value))
		x = x + width + GAP
	end
end

return FormatMultiSelect
