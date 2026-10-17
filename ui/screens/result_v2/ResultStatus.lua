local FlowContainer = require("gui.layout.FlowContainer")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.result_v2.ResultStatus : gui.layout.FlowContainer
---@operator call: ui.screens.result_v2.ResultStatus
---@field row gui.layout.FlowContainer
---@field icon ui.views.Image
---@field status ui.views.Label
---@field format ui.views.Label
local ResultStatus = FlowContainer + {}

local STATUS_COLOR = {0.616, 0.706, 0.941, 1}

function ResultStatus:new()
	FlowContainer.new(self, {direction = "column", gap = 6, align = 1})

	self.row = self:add(FlowContainer({direction = "row", gap = 8, align = 0.5}))
	self.icon = self.row:add(Image(Resources.sprites.icon_check, nil, STATUS_COLOR))
	self.status = self.row:add(Label({
		font_name = "bold",
		font_size = 28,
		color = STATUS_COLOR,
		text = "Ranked",
	}))
	self.row:fitContent()

	self.format = self:add(Label({
		font_name = "medium",
		font_size = 20,
		color = Colors.muted,
		text = "",
	}))
	self:fitContent()
end

---@param cvf ui.formatters.ChartviewFormatter
function ResultStatus:bind(cvf)
	local ranked = cvf:isRanked()
	-- Both icons have the same size, so the sprite can be swapped in place.
	self.icon.sprite = ranked and Resources.sprites.icon_check or Resources.sprites.icon_x
	self.status:setText(ranked and "Ranked" or "Unranked")
	local color = ranked and STATUS_COLOR or Colors.danger
	self.icon.color = color
	self.status.color = color
	self.format:setText(cvf:getFormat())

	self.row:fitContent()
	self:fitContent()
end

return ResultStatus
