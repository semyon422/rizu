local Checkbox = require("ui.views.form.Checkbox")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local Sounds = require("ui.Sounds")

---A boolean setting: a lane receptor that lights up like a pressed key.
---@class ui.modals.config.rows.ToggleRow : ui.views.form.Checkbox
---@operator call: ui.modals.config.rows.ToggleRow
---@field setting_row ui.modals.config.rows.SettingRow
---@field light number
local ToggleRow = Checkbox + {}

local LIGHT_SPEED = 14

---@param params ui.views.form.CheckboxParams
function ToggleRow:new(params)
	Checkbox.new(self, params)
	self.setting_row = SettingRow()
	self.light = self.checked and 1 or 0
	self:setSize(SettingRow.WIDTH, SettingRow.HEIGHT)
end

---@param checked boolean
---@param notify boolean?
function ToggleRow:setChecked(checked, notify)
	if notify and checked ~= self.checked then
		Sounds.play(checked and "checkbox_on" or "checkbox_off")
	end
	Checkbox.setChecked(self, checked, notify)
end

---@param dt number
function ToggleRow:update(dt)
	self.setting_row:update(self, dt)
	local target = self.checked and 1 or 0
	self.light = target + (self.light - target) * math.exp(-LIGHT_SPEED * dt)
end

function ToggleRow:draw()
	self.setting_row:draw(self, self.label_text)

	local sprites = Resources.sprites
	local off = self.setting_row:isHighlighted(self) and sprites.config_toggle_off_hover or sprites.config_toggle_off
	local width, height = off:getDimensions()
	local x = self.width - SettingRow.PADDING_X - width
	local y = math.floor((self.height - height) / 2)
	Painter.setColorRgb(1, 1, 1)
	if self.light < 0.99 then
		off:draw(x, y)
	end
	if self.light > 0.01 then
		Painter.setOpacity(self.light)
		sprites.config_toggle_on:draw(x, y)
		Painter.setOpacity(1)
	end
end

return ToggleRow
