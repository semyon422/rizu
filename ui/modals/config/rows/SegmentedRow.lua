local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local Sounds = require("ui.Sounds")

---@class ui.modals.config.rows.SegmentedRow : ui.views.form.SegmentedControl
---@operator call: ui.modals.config.rows.SegmentedRow
---@field setting_row ui.modals.config.rows.SettingRow
---@field track gui.NineSliceUsage?
---@field segment gui.NineSliceUsage?
---@field segments_width number
local SegmentedRow = SegmentedControl + {}

local PADDING = 3
local SEGMENT_HEIGHT = 30
local SEGMENT_PADDING_X = 14

---@param params ui.views.form.SegmentedControlParams
function SegmentedRow:new(params)
	SegmentedControl.new(self, params)
	self.setting_row = SettingRow()
	self.font = Resources.getFont("medium", 13)

	local width = 0
	for index, option in ipairs(self.options) do
		self.cell_widths[index] = self.font:getWidth(self.format(option)) + SEGMENT_PADDING_X * 2
		width = width + self.cell_widths[index]
	end
	self.segments_width = width
	self:setSize(SettingRow.WIDTH, SettingRow.HEIGHT)
end

---@return number x Left edge of the first segment.
function SegmentedRow:getSegmentsX()
	return self.width - SettingRow.PADDING_X - PADDING - self.segments_width
end

---@param screen_x number
---@param screen_y number
---@return integer? index
function SegmentedRow:getIndexAt(screen_x, screen_y)
	local local_x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local right = self:getSegmentsX()
	if local_x < right then
		return
	end
	for index, width in ipairs(self.cell_widths) do
		right = right + width
		if local_x <= right then
			return index
		end
	end
end

---@param value any
---@param notify boolean?
function SegmentedRow:setValue(value, notify)
	if notify and value ~= self.value then
		Sounds.play("click")
	end
	SegmentedControl.setValue(self, value, notify)
end

---@param dt number
function SegmentedRow:update(dt)
	self.setting_row:update(self, dt)
end

function SegmentedRow:draw()
	self.setting_row:draw(self, self.label_text)
	self.track = self.track or NineSliceUsage(Resources.nine_slices.config_v2_segmented)
	self.segment = self.segment or NineSliceUsage(Resources.nine_slices.config_v2_segment)

	local track_height = SEGMENT_HEIGHT + PADDING * 2
	local track_y = (self.height - track_height) / 2
	local segment_y = track_y + PADDING
	local segments_x = self:getSegmentsX()
	Painter.setColorRgb(1, 1, 1)
	love.graphics.push()
	love.graphics.translate(segments_x - PADDING, track_y)
	self.track:draw(self.segments_width + PADDING * 2, track_height)
	love.graphics.pop()

	local selected_index = self:getSelectedIndex()
	local hover_index = self.mouse_over and self:getIndexAt(love.mouse.getPosition())
	local text_y = math.floor(segment_y + (SEGMENT_HEIGHT - self.font:getHeight()) / 2)
	love.graphics.setFont(self.font)
	local x = segments_x
	for index, option in ipairs(self.options) do
		local width = self.cell_widths[index]
		if index == selected_index then
			Painter.setColorRgb(1, 1, 1)
			love.graphics.push()
			love.graphics.translate(x, segment_y)
			self.segment:draw(width, SEGMENT_HEIGHT)
			love.graphics.pop()
		end
		Painter.setColorTable(index == selected_index and Colors.accent
			or index == hover_index and Colors.text or Colors.muted)
		love.graphics.printf(self.format(option), x, text_y, width, "center")
		x = x + width
	end
end

return SegmentedRow
