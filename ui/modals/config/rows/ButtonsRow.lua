local ButtonRow = require("ui.views.form.ButtonRow")
local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local Sounds = require("ui.Sounds")

---A row of small outlined buttons, without a label.
---@class ui.modals.config.rows.ButtonsRow : ui.views.form.ButtonRow
---@operator call: ui.modals.config.rows.ButtonsRow
---@field setting_row ui.modals.config.rows.SettingRow
---@field button gui.NineSliceUsage?
---@field button_hover gui.NineSliceUsage?
local ButtonsRow = ButtonRow + {}

local BUTTON_HEIGHT = 30
local BUTTON_PADDING_X = 14
local GAP = 6
ButtonsRow.GAP = GAP

---@param params ui.views.form.ButtonRow.Params
function ButtonsRow:new(params)
	params.label = nil
	ButtonRow.new(self, params)
	self.setting_row = SettingRow()
	self.font = Resources.getFont("medium", 13)
	for index, button in ipairs(self.buttons) do
		self.button_widths[index] = self.font:getWidth(button.text) + BUTTON_PADDING_X * 2
	end
	self:setSize(SettingRow.WIDTH, SettingRow.HEIGHT)
end

---@return number x Left edge of the first button.
function ButtonsRow:getButtonsX()
	return SettingRow.PADDING_X
end

---@param screen_x number
---@param screen_y number
---@return integer? index
function ButtonsRow:getIndexAt(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local top = (self.height - BUTTON_HEIGHT) / 2
	if y < top or y > top + BUTTON_HEIGHT then
		return
	end
	local left = self:getButtonsX()
	for index, width in ipairs(self.button_widths) do
		if x >= left and x <= left + width then
			return index
		end
		left = left + width + GAP
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function ButtonsRow:onMouseClick(e)
	local handled = ButtonRow.onMouseClick(self, e)
	if handled then
		Sounds.play("click")
	end
	return handled
end

---@param e gui.KeyDownEvent?
---@return boolean activated
function ButtonsRow:activate(e)
	Sounds.play("click")
	return ButtonRow.activate(self, e)
end

---@param dt number
function ButtonsRow:update(dt)
	self.setting_row:update(self, dt)
end

function ButtonsRow:draw()
	self.setting_row:draw(self)
	local background_off = self.button or NineSliceUsage(Resources.nine_slices.config_v2_button)
	local background_on = self.button_hover or NineSliceUsage(Resources.nine_slices.config_v2_button_hover)
	self.button, self.button_hover = background_off, background_on

	local hovered ---@type integer?
	local inputs = self.screen and self.screen.inputs
	if self.mouse_over and inputs then
		hovered = self:getIndexAt(inputs.mouse_x, inputs.mouse_y)
	end
	local cursor = self:isKeyboardSelected() and self.cursor or nil

	local y = math.floor((self.height - BUTTON_HEIGHT) / 2)
	local text_y = math.floor(y + (BUTTON_HEIGHT - self.font:getHeight()) / 2)
	love.graphics.setFont(self.font)
	local x = self:getButtonsX()
	for index, button in ipairs(self.buttons) do
		local width = self.button_widths[index]
		local active = index == hovered or index == cursor
		Painter.setColorRgb(1, 1, 1)
		love.graphics.push()
		love.graphics.translate(x, y)
		local background = active and background_on or background_off
		background:draw(width, BUTTON_HEIGHT)
		love.graphics.pop()
		Painter.setColorTable(active and Colors.accent or Colors.text)
		love.graphics.printf(button.text, x, text_y, width, "center")
		x = x + width + GAP
	end
end

return ButtonsRow
