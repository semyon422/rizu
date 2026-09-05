local InputMode = require("chart.core.InputMode")
local FormControl = require("ui.views.form.FormControl")
local NineSliceUsage = require("gui.NineSliceUsage")
local Colors = require("ui.Colors")
local Format = require("sphere.views.Format")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local Textbox = require("ui.views.Textbox")
local UiActions = require("ui.UiActions")
local View = require("gui.View")

---@class ui.views.form.InputModeMultiSelect.EntryPopup : gui.View
---@operator call: ui.views.form.InputModeMultiSelect.EntryPopup
local EntryPopup = View + {}

local POPUP_WIDTH = 390
local POPUP_HEIGHT = 64
local TEXTBOX_X = 12
local TEXTBOX_Y = 12
local TEXTBOX_WIDTH = 294
local ADD_X = 314
local ADD_WIDTH = 64

---@param owner ui.views.form.InputModeMultiSelect
function EntryPopup:new(owner)
	View.new(self)
	self.owner = owner
	self.background = NineSliceUsage(Resources.nine_slices.song_select_search)
	self.button_background = NineSliceUsage(Resources.nine_slices.song_select_toolbar_control)
	self.font = Resources.getFont("bold", 14)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setLayoutIgnore(true)
	self:setSize(POPUP_WIDTH, POPUP_HEIGHT)

	self.textbox = self:add(Textbox({
		placeholder = "Input mode, e.g. 14K2S",
		blur_on_accept = false,
		blur_on_cancel = false,
		background = true,
	}))
	self.textbox:setPosition(TEXTBOX_X, TEXTBOX_Y):setSize(TEXTBOX_WIDTH, 40)
end

function EntryPopup:update()
	if self.focus_initialized then
		return
	end
	local inputs = assert(self.screen and self.screen.inputs)
	inputs:pushFocusScope(self)
	inputs:setKeyboardFocus(self.textbox, {control = false, shift = false, alt = false, super = false})
	self.focus_initialized = true
end

---@param inputs gui.Inputs
function EntryPopup:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.owner:close()
	elseif inputs:consumeActionJustPressed(UiActions.accept) then
		self.owner:addEnteredModes()
	end
end

---@return boolean
function EntryPopup:onMouseDown()
	return true
end

---@param e gui.MouseClickEvent
---@return boolean?
function EntryPopup:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local x, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	if x >= ADD_X and x <= ADD_X + ADD_WIDTH and y >= TEXTBOX_Y and y <= TEXTBOX_Y + 40 then
		self.owner:addEnteredModes()
		return true
	end
end

function EntryPopup:draw()
	--Painter.setColorTable(Colors.surface)
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)
	Painter.setColorTable(self.mouse_over and Colors.surface_raised or Colors.surface)
	love.graphics.push("transform")
	love.graphics.translate(ADD_X, TEXTBOX_Y)
	self.button_background:drawFixedScale(ADD_WIDTH, 40, assert(self.screen).ui_scale)
	love.graphics.pop()
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.printf("Add", ADD_X, TEXTBOX_Y + (40 - self.font:getHeight()) / 2, ADD_WIDTH, "center")
end

---@class ui.views.form.InputModeMultiSelectParams
---@field label string
---@field values? string[]
---@field popup_container ui.views.PopupContainer
---@field on_change? fun(values: string[])

---@class ui.views.form.InputModeMultiSelect : ui.views.form.FormControl, ui.views.PopupOwner
---@operator call: ui.views.form.InputModeMultiSelect
---@field values string[]
local InputModeMultiSelect = FormControl + {}

local WIDTH = 600
local HEIGHT = 59
local ROW_Y = 25
local ROW_HEIGHT = 34
local GAP = 8
local QUICK_VALUES = {"4K", "7K", "10K", "14K"}
local ELLIPSIS = "..."
local ADD = "+"

---@param text string
---@return string?
function InputModeMultiSelect.normalize(text)
	local value = text:lower():gsub("%s+", "")
	if value:match("^%d+k$") then
		return value:upper()
	end
	if value == "" then
		return
	end
	if value:gsub("%d+[ksp]", "") == "" then
		value = value:gsub("k", "key"):gsub("s", "scratch"):gsub("p", "pedal")
	end
	local ok, mode = pcall(InputMode, value)
	if ok and tostring(mode) ~= "" then
		return tostring(mode)
	end
end

---@param params ui.views.form.InputModeMultiSelectParams
function InputModeMultiSelect:new(params)
	FormControl.new(self)
	assert(params.popup_container, "InputModeMultiSelect requires a popup container")
	self.label = params.label
	self.values = {}
	self.popup_container = params.popup_container
	self.on_change = params.on_change
	self.font = Resources.getFont("medium", 16)
	self.background = NineSliceUsage(Resources.nine_slices.song_select_toolbar_control)
	self.handles_mouse_input = true
	self.opened = false
	self:setSize(WIDTH, HEIGHT)
	self:setValues(params.values or {})
end

---@param value string
---@return boolean
function InputModeMultiSelect:isSelected(value)
	for _, selected in ipairs(self.values) do
		if selected == value then return true end
	end
	return false
end

---@param values string[]
---@param notify boolean?
function InputModeMultiSelect:setValues(values, notify)
	local unique = {}
	local normalized = {}
	for _, value in ipairs(values) do
		value = self.normalize(value)
		if value and not unique[value] then
			unique[value] = true
			normalized[#normalized + 1] = value
		end
	end
	table.sort(normalized)
	self.values = normalized
	if notify and self.on_change then self.on_change(self.values) end
end

---@param value string
function InputModeMultiSelect:toggle(value)
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

---@return boolean added
function InputModeMultiSelect:addEnteredModes()
	local popup = self.popup
	if not popup then return false end
	local text = popup.textbox:getText()
	local values = {unpack(self.values)}
	local added = false
	for part in text:gmatch("[^,]+") do
		local value = self.normalize(part)
		if not value then
			popup.textbox:setText("")
			popup.textbox.placeholder = "Invalid input mode"
			return false
		end
		values[#values + 1] = value
		added = true
	end
	if not added then return false end
	self:setValues(values, true)
	Sounds.play("click")
	self:close()
	return true
end

---@return boolean opened
function InputModeMultiSelect:open()
	if self.opened then return false end
	local popup = EntryPopup(self)
	self.popup_container:open(self, popup, self)
	popup:addPosition(self.width - POPUP_WIDTH, ROW_Y + ROW_HEIGHT + GAP)
	self.popup = popup
	self.opened = true
	return true
end

---@return boolean closed
function InputModeMultiSelect:close()
	if not self.opened then return false end
	local popup = self.popup
	self.popup = nil
	self.opened = false
	if popup then
		if popup.focus_initialized then
			local inputs = assert(popup.screen and popup.screen.inputs)
			inputs:setKeyboardFocus(nil, {control = false, shift = false, alt = false, super = false})
			inputs:popFocusScope(popup)
		end
		if popup.parent then popup.parent:remove(popup) end
	end
	return true
end

---@param e gui.KeyDownEvent
---@return boolean activated
function InputModeMultiSelect:activate(e)
	return self:open()
end

---@param value string
---@return string
function InputModeMultiSelect:getLabel(value)
	return value:match("^%d+K$") and value or Format.inputMode(value)
end

---@return string[] values
---@return boolean overflowed
function InputModeMultiSelect:getVisibleValues()
	local values = {}
	local quick = {}
	for _, value in ipairs(QUICK_VALUES) do
		values[#values + 1] = value
		quick[value] = true
	end
	for _, value in ipairs(self.values) do
		if not quick[value] then values[#values + 1] = value end
	end

	local add_width = self.font:getWidth(ADD) + 28
	local available_width = self.width - add_width - GAP
	local ellipsis_width = self.font:getWidth(ELLIPSIS) + 28
	local visible = {}
	local x = 0
	for index, value in ipairs(values) do
		local width = self.font:getWidth(self:getLabel(value)) + 28
		local reserved = index < #values and (GAP + ellipsis_width) or 0
		if x + width + reserved > available_width then return visible, true end
		visible[#visible + 1] = value
		x = x + width + GAP
	end
	return visible, false
end

---@param screen_x number
---@param screen_y number
---@return string?
function InputModeMultiSelect:getValueAt(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	if y < ROW_Y or y > ROW_Y + ROW_HEIGHT then return end
	local left = 0
	for _, value in ipairs(self:getVisibleValues()) do
		local width = self.font:getWidth(self:getLabel(value)) + 28
		if x >= left and x <= left + width then return value end
		left = left + width + GAP
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function InputModeMultiSelect:onMouseClick(e)
	if e.button ~= 1 then return end
	local x, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	if y >= ROW_Y and y <= ROW_Y + ROW_HEIGHT then
		local add_width = self.font:getWidth(ADD) + 28
		if x >= self.width - add_width then
			if not self:close() then self:open() end
			Sounds.play("click")
			return true
		end
	end
	local value = self:getValueAt(e.x, e.y)
	if value then
		self:toggle(value)
		Sounds.play("click")
		return true
	end
end

---@param text string
---@param x number
---@param selected boolean
---@return number next_x
function InputModeMultiSelect:drawButton(text, x, selected)
	local width = self.font:getWidth(text) + 28
	Painter.setColorTable(selected and Colors.accent or Colors.surface)
	love.graphics.push("transform")
	love.graphics.translate(x, ROW_Y)
	self.background:draw(width, ROW_HEIGHT)
	love.graphics.pop()
	Painter.setColorTable(selected and Colors.panel or Colors.text)
	love.graphics.printf(text, x, ROW_Y + (ROW_HEIGHT - self.font:getHeight()) / 2, width, "center")
	return x + width + GAP
end

function InputModeMultiSelect:draw()
	Painter.snapToPixel()
	love.graphics.setFont(self.font)
	Painter.setColorTable(Colors.text)
	love.graphics.print(self.label, 0, 0)

	local x = 0
	local values, overflowed = self:getVisibleValues()
	for _, value in ipairs(values) do
		x = self:drawButton(self:getLabel(value), x, self:isSelected(value))
	end
	if overflowed then x = self:drawButton(ELLIPSIS, x, false) end
	local add_width = self.font:getWidth(ADD) + 28
	self:drawButton(ADD, self.width - add_width, self.opened)
end

return InputModeMultiSelect
