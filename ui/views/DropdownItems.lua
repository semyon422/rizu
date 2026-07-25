local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@alias ui.views.DropdownFormat fun(value: any): string

---@class ui.views.DropdownItems : gui.View
---@operator call: ui.views.DropdownItems
---@field options any[]
---@field format ui.views.DropdownFormat
---@field row_height number
---@field font love.Font
---@field selected_index integer?
---@field on_select fun(value: any, index: integer)
local DropdownItems = View + {}

---@param options any[]
---@param format ui.views.DropdownFormat
---@param width number
---@param row_height number
---@param on_select fun(value: any, index: integer)
function DropdownItems:new(options, format, width, row_height, on_select)
	View.new(self)
	self.options = options
	self.format = format
	self.row_height = row_height
	self.on_select = on_select
	self.font = Resources.getFont("regular", 24)
	self.selected_index = nil
	self.handles_mouse_input = true
	self:setSize(width, row_height * #options)
	self:setLayoutIgnore(true)
end

---@param value any
function DropdownItems:setValue(value)
	self.selected_index = nil
	for i, option in ipairs(self.options) do
		if option == value then
			self.selected_index = i
			return
		end
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function DropdownItems:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	local _, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	local index = math.floor(y / self.row_height) + 1
	local value = self.options[index]
	if value ~= nil then
		self.on_select(value, index)
	end
	return true
end

function DropdownItems:draw()
	local lg = love.graphics
	local _, mouse_y = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
	local hover_index = self.mouse_over and math.floor(mouse_y / self.row_height) + 1 or nil
	Painter.setColorRgb(0.10, 0.10, 0.13)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	lg.setFont(self.font)
	for i, value in ipairs(self.options) do
		local y = (i - 1) * self.row_height
		if i == hover_index then
			Painter.setColorRgb(0.25, 0.22, 0.33)
			lg.rectangle("fill", 0, y, self.width, self.row_height)
		elseif i == self.selected_index then
			Painter.setColorRgb(0.20, 0.18, 0.27)
			lg.rectangle("fill", 0, y, self.width, self.row_height)
		end
		Painter.setColorRgb(0.95, 0.95, 1)
		lg.print(self.format(value), 10, y + (self.row_height - self.font:getHeight()) / 2)
	end
	Painter.setColorRgb(0.45, 0.42, 0.55)
	lg.rectangle("line", 0, 0, self.width, self.height)
end

return DropdownItems
