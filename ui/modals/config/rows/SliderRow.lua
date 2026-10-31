local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local Slider = require("ui.views.form.Slider")
local Sounds = require("ui.Sounds")

---A number setting: the label and value above a full-width track.
---@class ui.modals.config.rows.SliderRow : ui.views.form.Slider
---@operator call: ui.modals.config.rows.SliderRow
---@field setting_row ui.modals.config.rows.SettingRow
local SliderRow = Slider + {}

local HEIGHT = 66
local TEXT_Y = 10
local TRACK_TOP = 38
local TRACK_Y = 45
local TRACK_HEIGHT = 4
local THUMB_RADIUS = 7
local THUMB_HOVER_SCALE = 1.2

---@param params ui.views.form.SliderParams
function SliderRow:new(params)
	Slider.new(self, params)
	self.setting_row = SettingRow()
	self.font = Resources.getFont("medium", 14)
	self:setSize(SettingRow.WIDTH, HEIGHT)
end

---@param value number
---@param notify boolean?
function SliderRow:setValue(value, notify)
	if notify and value ~= self.value then
		Sounds.play("slider_tick")
	end
	Slider.setValue(self, value, notify)
end

---@return number start
---@return number travel
function SliderRow:getTrack()
	return SettingRow.PADDING_X + THUMB_RADIUS, self.width - (SettingRow.PADDING_X + THUMB_RADIUS) * 2
end

---Only the track takes pointer input, so a click on the label does not change the value.
---@param screen_x number
---@param screen_y number
---@return boolean
function SliderRow:isOverTrack(screen_x, screen_y)
	local _, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	return y >= TRACK_TOP
end

---@param e gui.DragStartEvent
---@return boolean?
function SliderRow:onDragStart(e)
	if self:isOverTrack(e.x, e.y) then
		return Slider.onDragStart(self, e)
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function SliderRow:onMouseClick(e)
	if self:isOverTrack(e.x, e.y) then
		return Slider.onMouseClick(self, e)
	end
end

---@param dt number
function SliderRow:update(dt)
	self.setting_row:update(self, dt)
end

function SliderRow:draw()
	local setting_row = self.setting_row
	setting_row:draw(self)

	local padding = SettingRow.PADDING_X
	love.graphics.setFont(self.font)
	Painter.setColorTable(Colors.text)
	love.graphics.print(self.label_text, padding, TEXT_Y)
	if self.value_format then
		Painter.setColorTable(Colors.accent)
		love.graphics.printf(self.value_format(self.value), padding, TEXT_Y, self.width - padding * 2, "right")
	end

	local start, travel = self:getTrack()
	local thumb_x = start + travel * (self.value - self.min) / (self.max - self.min)
	local pixel = Resources.sprites.pixel
	Painter.setColorTable(Colors.background)
	pixel:draw(padding, TRACK_Y - TRACK_HEIGHT / 2, 0, self.width - padding * 2, TRACK_HEIGHT)
	Painter.setColorTable(Colors.accent)
	pixel:draw(padding, TRACK_Y - TRACK_HEIGHT / 2, 0, thumb_x - padding, TRACK_HEIGHT)

	local thumb = Resources.sprites.config_v2_slider_thumb
	local thumb_width, thumb_height = thumb:getDimensions()
	local scale = 1 + (THUMB_HOVER_SCALE - 1) * setting_row.highlight
	Painter.setColorRgb(1, 1, 1)
	thumb:draw(thumb_x, TRACK_Y, 0, scale, scale, thumb_width / 2, thumb_height / 2)
end

return SliderRow
