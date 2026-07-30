local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@alias ui.views.form.DropdownFormat fun(value: any): string

---@class ui.views.form.DropdownItems : gui.View
---@operator call: ui.views.form.DropdownItems
---@field options any[]
---@field format ui.views.form.DropdownFormat
---@field row_height number
---@field font love.Font
---@field chevron gui.Sprite
---@field selected_index integer?
---@field on_select fun(value: any, index: integer)
---@field dropdown ui.views.form.Dropdown
local DropdownItems = View + {}

local BODY_Y = 25

---@param dropdown ui.views.form.Dropdown
---@param options any[]
---@param format ui.views.form.DropdownFormat
---@param width number
---@param row_height number
---@param on_select fun(value: any, index: integer)
function DropdownItems:new(dropdown, options, format, width, row_height, on_select)
	View.new(self)
	self.dropdown = dropdown
	self.options = options
	self.format = format
	self.row_height = row_height
	self.on_select = on_select
	self.font = Resources.getFont("medium", 16)
	self.chevron = Resources.sprites.icon_chevron
	self.selected_index = nil
	self.handles_mouse_input = true
	self:setSize(width, BODY_Y + row_height * #options)
	self:setLayoutIgnore(true)
end

function DropdownItems:open()
	self:setEnabled(true)
end

function DropdownItems:close()
	self:setEnabled(false)
	if self.parent then
		self.parent:remove(self)
	end
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

---@param display_index integer
---@return any value
---@return integer option_index
function DropdownItems:getDisplayOption(display_index)
	local selected_index = assert(self.selected_index, "dropdown value must be one of its options")
	if display_index == 1 then
		return self.options[selected_index], selected_index
	end
	local option_index = display_index - 1
	if option_index >= selected_index then
		option_index = option_index + 1
	end
	return self.options[option_index], option_index
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function DropdownItems:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	self.dropdown:disableFormNavigation()
	local _, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	local display_index = math.floor((y - BODY_Y) / self.row_height) + 1
	if y >= BODY_Y and display_index <= #self.options then
		local value, option_index = self:getDisplayOption(display_index)
		self.on_select(value, option_index)
	end
	return true
end

function DropdownItems:draw()
	Painter.snapToPixel()
	local lg = love.graphics
	local _, mouse_y = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
	local hover_index = self.mouse_over and mouse_y >= BODY_Y
		and math.floor((mouse_y - BODY_Y) / self.row_height) + 1 or nil
	local body_height = self.height - BODY_Y

	lg.setColor(Colors.background)
	lg.rectangle("fill", 0, BODY_Y, self.width, body_height, 8, 8)
	lg.setFont(self.font)
	lg.setColor(Colors.text)
	lg.print(self.dropdown.label_text, 0, 0)
	for display_index = 1, #self.options do
		local value = self:getDisplayOption(display_index)
		local y = BODY_Y + (display_index - 1) * self.row_height
		if display_index == hover_index then
			lg.setColor(Colors.hover)
			lg.rectangle("fill", 1, y, self.width - 1, self.row_height)
		end
		lg.setColor(Colors.text)
		lg.print(self.format(value), 9, y + (self.row_height - self.font:getHeight()) / 2)
	end

	lg.setColor(Colors.text)
	self.chevron:draw(self.width - 8, BODY_Y + self.row_height - 8, math.pi)
	lg.setLineWidth(2)
	lg.setColor(Colors.outline)
	lg.rectangle("line", 0, BODY_Y, self.width, body_height, 8, 8)
end

return DropdownItems
