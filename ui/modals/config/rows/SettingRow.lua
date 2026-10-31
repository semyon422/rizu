local class = require("class")
local Colors = require("ui.Colors")
local FormNavigation = require("ui.views.form.FormNavigation")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---The look every settings row shares: one piece of a rounded group, highlighted while selected.
---@class ui.modals.config.rows.SettingRow
---@operator call: ui.modals.config.rows.SettingRow
---@field background gui.NineSliceUsage?
---@field hover_background gui.NineSliceUsage?
---@field form ui.views.form.Form?
---@field first boolean
---@field last boolean
---@field highlight number
---@field highlighted boolean
local SettingRow = class()

SettingRow.WIDTH = 736
SettingRow.HEIGHT = 56
SettingRow.PADDING_X = 16

local MARKER_X = 6
local MARKER_Y = 8
local MARKER_WIDTH = 3
local FADE_SPEED = 20

function SettingRow:new()
	self.form = nil
	self.first = true
	self.last = true
	self.highlight = 0
	self.highlighted = false
end

---@param form ui.views.form.Form?
---@param first boolean First row of its group: rounded top.
---@param last boolean Last row of its group: rounded bottom.
function SettingRow:place(form, first, last)
	self.form = form
	self.first = first
	self.last = last
end

---Selected by the keyboard, or hovered.
---@param view gui.View
---@return boolean
function SettingRow:isHighlighted(view)
	local form = self.form
	return form ~= nil and form.selected_control == view
		and (form.navigation == FormNavigation.Keyboard or view.mouse_over)
end

---@param view gui.View
---@param dt number
function SettingRow:update(view, dt)
	local highlighted = self:isHighlighted(view)
	if highlighted and not self.highlighted then
		Sounds.play("hover")
	end
	self.highlighted = highlighted
	local target = highlighted and 1 or 0
	self.highlight = target + (self.highlight - target) * math.exp(-FADE_SPEED * dt)
end

---@param view gui.View
---@param label string?
function SettingRow:draw(view, label)
	local width, height = view.width, view.height
	local background = self.background or NineSliceUsage(Resources.nine_slices.config_v2_row)
	local hover_background = self.hover_background or NineSliceUsage(Resources.nine_slices.config_v2_row_hover)
	self.background, self.hover_background = background, hover_background
	background:setOpenEdges(not self.first, not self.last)
	hover_background:setOpenEdges(not self.first, not self.last)

	Painter.snapToPixel()
	Painter.setColorRgb(1, 1, 1)
	background:draw(width, height)
	local highlight = self.highlight
	if highlight > 0.01 then
		Painter.setOpacity(highlight)
		hover_background:draw(width, height)
		Painter.setColorTable(Colors.muted)
		Resources.sprites.pixel:draw(MARKER_X, MARKER_Y, 0, MARKER_WIDTH, height - MARKER_Y * 2)
		Painter.setOpacity(1)
	end
	if not self.first then
		Painter.setColorTable(Colors.divider)
		Resources.sprites.pixel:draw(1, 0, 0, width - 2, 1)
	end
	if label then
		local font = Resources.getFont("medium", 14)
		Painter.setColorTable(Colors.text)
		love.graphics.setFont(font)
		love.graphics.print(label, SettingRow.PADDING_X, math.floor((height - font:getHeight()) / 2))
	end
end

return SettingRow
