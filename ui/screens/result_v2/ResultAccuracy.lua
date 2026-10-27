local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")

---@class ui.screens.result_v2.ResultAccuracy : gui.layout.FlowContainer
---@operator call: ui.screens.result_v2.ResultAccuracy
---@field label ui.views.Label
---@field score_system ui.views.Label
---@field accuracy ui.views.Label
---@field percent ui.views.Label
---@field grade ui.views.Label
---@field fail ui.views.Label
---@field header gui.layout.FlowContainer
---@field hero gui.layout.FlowContainer
---@field number gui.layout.FlowContainer
local ResultAccuracy = FlowContainer + {}

function ResultAccuracy:new()
	FlowContainer.new(self, {direction = "column", gap = 4})

	self.header = self:add(FlowContainer({direction = "row", gap = 16, align = "baseline"}))
	self.label = self.header:add(Label({
		font_name = "bold",
		font_size = 20,
		color = Colors.muted,
		text = "ACCURACY",
	}))
	self.score_system = self.header:add(Label({
		font_name = "medium",
		font_size = 24,
		color = Colors.accent,
		text = "",
	}))
	self.header:fitContent()

	self.hero = self:add(FlowContainer({direction = "row", gap = 28, align = "baseline"}))
	self.number = self.hero:add(FlowContainer({direction = "row", gap = 6, align = "baseline"}))
	self.accuracy = self.number:add(Label({
		font_name = "bold",
		font_size = 120,
		color = Colors.grade_s,
		text = "0.00",
	}))
	self.percent = self.number:add(Label({
		font_name = "bold",
		font_size = 52,
		color = Colors.grade_s,
		text = "%",
	}))
	self.number:fitContent()
	self.grade = self.hero:add(Label({
		font_name = "bold",
		font_size = 76,
		color = Colors.grade_s,
		text = "D",
	}))
	self.fail = self.hero:add(Label({
		font_name = "bold",
		font_size = 76,
		color = Colors.danger,
		text = "",
	}))
	self.hero:fitContent()
	self:fitContent()
end

---@param accuracy number 0..1
---@param text string
---@param ssf ui.formatters.ScoreSystemFormatter
---@param passed boolean
function ResultAccuracy:bind(accuracy, text, ssf, passed)
	local grade = ssf:getGrade(accuracy)
	local color = ssf:getGradeColor(grade)

	-- The percent sign is a separate, smaller label.
	self.accuracy:setText((text:gsub("%%$", "")))
	self.grade:setText(grade)
	self.fail:setText(passed and "" or "FAIL")
	self.score_system:setText(ssf:getName())
	self.accuracy.color = color
	self.percent.color = color
	self.grade.color = color

	self.number:fitContent()
	self.header:fitContent()
	self.hero:fitContent()
	self:fitContent()
end

return ResultAccuracy
