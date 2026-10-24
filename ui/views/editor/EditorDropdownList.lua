local View = require("gui.View")
local EditorRow = require("ui.views.editor.EditorRow")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---The open list of an editor dropdown: flat rows, the current value marked with an accent bar.
---@class ui.views.editor.EditorDropdownList : gui.View
---@operator call: ui.views.editor.EditorDropdownList
---@field options any[]
---@field value any
---@field format fun(value: any): string
---@field on_select fun(value: any)
---@field font love.Font
local EditorDropdownList = View + {}

local ROW_HEIGHT = EditorRow.HEIGHT
local MARK_WIDTH = 2

---@param options any[]
---@param value any
---@param format fun(value: any): string
---@param width number
---@param on_select fun(value: any)
function EditorDropdownList:new(options, value, format, width, on_select)
	View.new(self)
	self.options = options
	self.value = value
	self.format = format
	self.on_select = on_select
	self.font = Resources.getFont("regular", 16)
	self.handles_mouse_input = true
	self:setSize(width, ROW_HEIGHT * #options)
	self:setLayoutIgnore(true)
end

---@param screen_x number
---@param screen_y number
---@return integer?
function EditorDropdownList:getIndexAt(screen_x, screen_y)
	local _, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local index = math.floor(y / ROW_HEIGHT) + 1
	if y >= 0 and self.options[index] ~= nil then return index end
end

---@param e gui.MouseDownEvent
---@return boolean?
function EditorDropdownList:onMouseDown(e)
	if e.button ~= 1 then return end
	local index = self:getIndexAt(e.x, e.y)
	if index then self.on_select(self.options[index]) end
	return true
end

function EditorDropdownList:draw()
	Painter.snapToPixel()
	local hover = self.mouse_over and self:getIndexAt(love.mouse.getPosition())
	EditorRow.fillRect(Colors.surface, 0, 0, self.width, self.height)
	love.graphics.setFont(self.font)
	local text_y = math.floor((ROW_HEIGHT - self.font:getHeight()) / 2)
	for i, option in ipairs(self.options) do
		local y = (i - 1) * ROW_HEIGHT
		if i == hover then
			EditorRow.fillRect(Colors.surface_raised, 0, y, self.width, ROW_HEIGHT)
		end
		if option == self.value then
			EditorRow.fillRect(Colors.accent, 0, y, MARK_WIDTH, ROW_HEIGHT)
		end
		Painter.setColorTable(Colors.text)
		love.graphics.print(self.format(option), EditorRow.TEXT_X, y + text_y)
	end
	Painter.setColorTable(Colors.outline)
	Painter.rectangleLineFixed(0, 0, self.width, self.height, 1)
end

return EditorDropdownList
