local EditorRow = require("ui.views.editor.EditorRow")
local EditorDropdownList = require("ui.views.editor.EditorDropdownList")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.editor.EditorDropdownParams
---@field label string?
---@field options any[]
---@field value any
---@field width number
---@field format (fun(value: any): string)?
---@field popup_container ui.views.PopupContainer
---@field on_change fun(value: any)?

---A field showing the current option. A click opens the options below it, or above when they do
---not fit under it.
---@class ui.views.editor.EditorDropdown : ui.views.editor.EditorRow, ui.views.PopupOwner
---@operator call: ui.views.editor.EditorDropdown
---@field options any[]
---@field value any
---@field format fun(value: any): string
---@field popup_container ui.views.PopupContainer
---@field on_change fun(value: any)?
---@field list ui.views.editor.EditorDropdownList?
local EditorDropdown = EditorRow + {}

---@param params ui.views.editor.EditorDropdownParams
function EditorDropdown:new(params)
	EditorRow.new(self, params.label, params.width)
	self.popup_container = assert(params.popup_container, "dropdown requires a popup container")
	self.options = params.options
	self.value = params.value
	self.format = params.format or tostring
	self.on_change = params.on_change
	self.list = nil
end

---@param value any
---@param notify boolean?
function EditorDropdown:setValue(value, notify)
	if value == self.value then return end
	self.value = value
	if notify and self.on_change then self.on_change(value) end
end

---@return boolean opened
function EditorDropdown:open()
	if self.list or #self.options == 0 then return false end
	local x, width = self:getField()
	local list = EditorDropdownList(self.options, self.value, self.format, width, function(value)
		self:close()
		self:setValue(value, true)
	end)
	local container = self.popup_container
	local screen_x, bottom = self.world_transform:transformPoint(x, self.height)
	local _, top = self.world_transform:transformPoint(x, 0)
	local list_x, list_y = container.world_transform:inverseTransformPoint(screen_x, bottom)
	local list_height = list:getAuthoredHeight()
	if list_y + list_height > container.height then
		list_x, list_y = container.world_transform:inverseTransformPoint(screen_x, top)
		list_y = list_y - list_height
	end
	list:setPosition(list_x, list_y)
	container:open(self, list)
	self.list = list
	return true
end

---@return boolean closed
function EditorDropdown:close()
	local list = self.list
	if not list then return false end
	self.list = nil
	if list.parent then list.parent:remove(list) end
	return true
end

---@param e gui.MouseClickEvent
---@return boolean?
function EditorDropdown:onMouseClick(e)
	if e.button ~= 1 then return end
	if not self:close() then self:open() end
	return true
end

function EditorDropdown:unload()
	self:close()
end

function EditorDropdown:draw()
	Painter.snapToPixel()
	self:drawLabel()
	local x, width = self:getField()
	local active = self.mouse_over or self.list
	EditorRow.fillRect(active and Colors.surface_raised or Colors.surface, x, 0, width, self.height)
	Painter.setColorTable(Colors.text)
	local chevron = Resources.sprites.icon_chevron
	local chevron_width, chevron_height = chevron:getDimensions()
	local value_text = self.value == nil and "" or self.format(self.value)
	self:printText(value_text, x + EditorRow.TEXT_X, width - EditorRow.TEXT_X - chevron_width, "left")
	Painter.setColorTable(Colors.muted)
	chevron:draw(x + width - chevron_width - 3, math.floor((self.height - chevron_height) / 2))
end

return EditorDropdown
