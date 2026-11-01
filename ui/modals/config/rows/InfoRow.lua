local FlowContainer = require("gui.layout.FlowContainer")
local SettingRow = require("ui.modals.config.rows.SettingRow")
local View = require("gui.View")

---Read-only content stacked in one row of a group, such as device status or a preview.
---@class ui.modals.config.rows.InfoRow : gui.View
---@operator call: ui.modals.config.rows.InfoRow
---@field setting_row ui.modals.config.rows.SettingRow
---@field content gui.layout.FlowContainer
local InfoRow = View + {}

function InfoRow:new()
	View.new(self)
	self.setting_row = SettingRow()
	self.content = self:add(FlowContainer({direction = "column", gap = 4, padding = {SettingRow.PADDING_X, 10, SettingRow.PADDING_X, 10}}))
	self:setWidth(SettingRow.WIDTH)
end

---@param view gui.View
function InfoRow:addContent(view)
	self.content:add(view)
	self.content:fitContent()
	self:setHeight(self.content:getAuthoredHeight())
end

function InfoRow:draw()
	self.setting_row:draw(self)
end

return InfoRow
