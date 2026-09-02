local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")

local lg = love.graphics

---@class ui.screens.song_select.DropdownOption
---@field label string
---@field value any

---@class ui.screens.song_select.DropdownItems : gui.View
---@operator call: ui.screens.song_select.DropdownItems
---@field dropdown ui.screens.song_select.Dropdown
---@field options ui.screens.song_select.DropdownOption[]
local DropdownItems = View + {}

local ROW_HEIGHT = 42

---@param dropdown ui.screens.song_select.Dropdown
---@param options ui.screens.song_select.DropdownOption[]
function DropdownItems:new(dropdown, options)
	View.new(self)
	self.dropdown = dropdown
	self.options = options
	self.font = Resources.getFont("medium", 14)
	self.handles_mouse_input = true
	self:setLayoutIgnore(true)
	self:setSize(dropdown.width, ROW_HEIGHT * #options)
end

---@return integer?
function DropdownItems:getHoverIndex()
	if not self.mouse_over then return end
	local _, y = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
	local index = math.floor(y / ROW_HEIGHT) + 1
	if self.options[index] then return index end
end

function DropdownItems:draw()
	Painter.snapToPixel()
	local hover_index = self:getHoverIndex()
	Painter.setColorTable(Colors.panel)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	lg.setFont(self.font)
	for index, option in ipairs(self.options) do
		local y = (index - 1) * ROW_HEIGHT
		if index == hover_index then
			Painter.setColorTable(Colors.surface_raised)
			Resources.sprites.pixel:draw(1, y, 0, self.width - 2, ROW_HEIGHT)
		end
		Painter.setColorTable(Colors.text)
		lg.print(option.label, 14, y + (ROW_HEIGHT - self.font:getHeight()) / 2)
	end
	Painter.setColorTable(Colors.outline)
	Painter.rectangleLineFixed(0, 0, self.width, self.height, 1)
end

---@param e gui.MouseDownEvent
---@return boolean?
function DropdownItems:onMouseDown(e)
	if e.button ~= 1 then return end
	local index = self:getHoverIndex()
	if index then
		self.dropdown:selectOption(self.options[index])
	end
	return true
end

return DropdownItems
