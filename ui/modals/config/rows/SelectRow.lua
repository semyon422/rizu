local Colors = require("ui.Colors")
local Dropdown = require("ui.views.form.Dropdown")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local Sounds = require("ui.Sounds")
local View = require("gui.View")

---@class ui.modals.config.rows.SelectRow : ui.views.form.Dropdown
---@operator call: ui.modals.config.rows.SelectRow
---@field setting_row ui.modals.config.rows.SettingRow
---@field field gui.NineSliceUsage?
local SelectRow = Dropdown + {}

local FIELD_WIDTH = 220
local FIELD_HEIGHT = 36
local TEXT_X = 12
local CHEVRON_SIZE = 16

---@param params ui.views.form.DropdownParams
function SelectRow:new(params)
	params.row_height = params.row_height or FIELD_HEIGHT
	Dropdown.new(self, params)
	self.setting_row = SettingRow()
	self.font = Resources.getFont("medium", 14)
	self:setSize(SettingRow.WIDTH, SettingRow.HEIGHT)

	-- The options open over the field rather than over the whole row.
	self.popup_source = self:add(View())
	self.popup_source:anchorFixed(
		SettingRow.WIDTH - SettingRow.PADDING_X - FIELD_WIDTH,
		(SettingRow.HEIGHT - FIELD_HEIGHT) / 2,
		FIELD_WIDTH,
		FIELD_HEIGHT
	)
	self.popup_label = false
end

---@return boolean opened
function SelectRow:open()
	local opened = Dropdown.open(self)
	if opened then
		Sounds.play("dropdown_open")
	end
	return opened
end

---@param value any
---@param notify boolean?
function SelectRow:setValue(value, notify)
	if notify then
		Sounds.play("click")
	end
	Dropdown.setValue(self, value, notify)
end

---@param dt number
function SelectRow:update(dt)
	self.setting_row:update(self, dt)
end

function SelectRow:draw()
	self.setting_row:draw(self, self.label_text)
	self.field = self.field or NineSliceUsage(Resources.nine_slices.config_v2_field)

	local field = self.popup_source
	Painter.setColorRgb(1, 1, 1)
	love.graphics.push()
	love.graphics.translate(field.x, field.y)
	self.field:draw(field.width, field.height)

	local value_text = self.value == nil and "" or self.format(self.value)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(value_text, TEXT_X, math.floor((field.height - self.font:getHeight()) / 2))
	local chevron = self.chevron
	local scale = CHEVRON_SIZE / chevron:getWidth()
	Painter.setColorTable(Colors.muted)
	chevron:draw(field.width - CHEVRON_SIZE - 10, (field.height - CHEVRON_SIZE) / 2, 0, scale, scale)
	love.graphics.pop()
end

return SelectRow
