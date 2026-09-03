local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local DropdownItems = require("ui.screens.song_select.DropdownItems")

local lg = love.graphics

---@class ui.screens.song_select.Dropdown.Config
---@field label string
---@field options ui.screens.song_select.DropdownOption[]
---@field value any
---@field popup_container ui.views.PopupContainer
---@field icon? gui.Sprite
---@field on_change? fun(value: any)

---@class ui.screens.song_select.Dropdown : gui.View, ui.views.PopupOwner
---@operator call: ui.screens.song_select.Dropdown
---@field options ui.screens.song_select.DropdownOption[]
---@field popup_container ui.views.PopupContainer
local Dropdown = View + {}

---@param config ui.screens.song_select.Dropdown.Config
function Dropdown:new(config)
	View.new(self)
	self.label = config.label
	self.options = config.options
	self.value = config.value
	self.popup_container = config.popup_container
	self.icon = config.icon
	self.on_change = config.on_change
	self.label_font = Resources.getFont("bold", 9)
	self.value_font = Resources.getFont("bold", 14)
	self.handles_mouse_input = true
	self.opened = false
	self.background = NineSliceUsage(Resources.nine_slices.song_select_toolbar_control)
end

---@param value any
function Dropdown:setValue(value)
	self.value = value
end

---@param options ui.screens.song_select.DropdownOption[]
---@param value any
function Dropdown:setOptions(options, value)
	self:close()
	self.options = options
	self.value = value
end

---@return string
function Dropdown:getValueLabel()
	for _, option in ipairs(self.options) do
		if option.value == self.value then return option.label end
	end
	return self.options[1] and self.options[1].label or ""
end

function Dropdown:open()
	if self.opened or #self.options == 0 then return false end
	local items = DropdownItems(self, self.options)
	self.popup_container:open(self, items, self)
	items:setOffset(0, self.height)
	self.items = items
	self.opened = true
	return true
end

function Dropdown:close()
	if not self.opened then return false end
	self.opened = false
	local items = self.items
	self.items = nil
	if items and items.parent then items.parent:remove(items) end
	return true
end

---@param option ui.screens.song_select.DropdownOption
function Dropdown:selectOption(option)
	self.value = option.value
	self:close()
	if self.on_change then self.on_change(option.value) end
end

---@param e gui.MouseClickEvent
---@return boolean?
function Dropdown:onMouseClick(e)
	if e.button ~= 1 then return end
	if not self:close() then self:open() end
	return true
end

function Dropdown:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.surface)
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)
	local text_x = self.icon and 45 or 14
	if self.icon then
		Painter.setColorTable(Colors.accent)
		local width, height = self.icon:getDimensions()
		local scale = math.min(20 / width, 20 / height)
		self.icon:draw(14, (self.height - height * scale) / 2, 0, scale, scale)
	end

	Painter.setColorTable(Colors.muted)
	lg.setFont(self.label_font)
	lg.print(self.label, text_x, 7)
	Painter.setColorTable(Colors.text)
	lg.setFont(self.value_font)
	lg.print(self:getValueLabel(), text_x, 21)

	Painter.setColorTable(Colors.muted)
	local chevron = Resources.sprites.icon_chevron
	local width, height = chevron:getDimensions()
	chevron:draw(self.width - width - 12, (self.height - height) / 2)
end

return Dropdown
