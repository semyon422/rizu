local Keybind = require("ui.views.form.Keybind")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local Sounds = require("ui.Sounds")

---@class ui.modals.config.rows.KeybindRow : ui.views.form.Keybind
---@operator call: ui.modals.config.rows.KeybindRow
---@field setting_row ui.modals.config.rows.SettingRow
---@field field gui.NineSliceUsage?
local KeybindRow = Keybind + {}

local FIELD_WIDTH = 220
local FIELD_HEIGHT = 36
local TEXT_X = 12

---@param params ui.views.form.KeybindParams
function KeybindRow:new(params)
	params.width = SettingRow.WIDTH
	params.binding_width = FIELD_WIDTH
	Keybind.new(self, params)
	self.setting_row = SettingRow()
	self.font = Resources.getFont("medium", 14)
	self:setSize(SettingRow.WIDTH, SettingRow.HEIGHT)
end

---@param modifiers gui.UIEvent
---@return boolean activated
function KeybindRow:activate(modifiers)
	Sounds.play("click")
	return Keybind.activate(self, modifiers)
end

---@param dt number
function KeybindRow:update(dt)
	self.setting_row:update(self, dt)
end

function KeybindRow:draw()
	self.setting_row:draw(self, self.label_text)
	self.field = self.field or NineSliceUsage(Resources.nine_slices.config_v2_field)

	local x = self.width - SettingRow.PADDING_X - FIELD_WIDTH
	local y = (self.height - FIELD_HEIGHT) / 2
	Painter.setColorRgb(1, 1, 1)
	love.graphics.push()
	love.graphics.translate(x, y)
	self.field:draw(FIELD_WIDTH, FIELD_HEIGHT)
	local text, color = self:getBindingText()
	Painter.setColorTable(color)
	love.graphics.setFont(self.font)
	love.graphics.print(text, TEXT_X, math.floor((FIELD_HEIGHT - self.font:getHeight()) / 2))
	love.graphics.pop()
end

return KeybindRow
