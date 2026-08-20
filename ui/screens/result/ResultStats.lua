local FlowContainer = require("gui.layout.FlowContainer")
local BMFontLabel = require("ui.views.BMFontLabel")
local Colors = require("ui.Colors")

---@class ui.screens.result.ResultStats : gui.layout.FlowContainer
---@operator call: ui.screens.result.ResultStats
local ResultStats = FlowContainer + {}

function ResultStats:new()
	FlowContainer.new(self, {
		direction = "column",
		align = 0.5,
		gap = 20,
	})

	self.grade = self:add(BMFontLabel({
		font_name = "outline_regular",
		font_size = 64,
		text = "D",
		color = Colors.grade_d
	}))

	self.accuracy = self:add(BMFontLabel({
		font_name = "outline_regular",
		font_size = 96,
		text = "0.00%",
		color = Colors.grade_s
	}))

	self.ma_ratio = BMFontLabel({
		font_name = "outline_regular",
		font_size = 48,
		text = "1:1",
		color = Colors.grade_x
	})

	self.pa_ratio = BMFontLabel({
		font_name = "outline_regular",
		font_size = 48,
		text = "1:1",
		color = Colors.grade_s
	})

	self.misses = BMFontLabel({
		font_name = "outline_regular",
		font_size = 48,
		text = "0x",
		color = Colors.grade_d
	})

	self.numbers = self:add(FlowContainer({
		direction = "row",
		gap = 20,
		self.ma_ratio,
		self.pa_ratio,
		self.misses,
	}))
	self.numbers:fitContent()
	self:fitContent()

	self:setOffset(0, -14)
end

---@param accuracy_source rizu.IAccuracySource
---@param judges_source rizu.IJudgesSource
---@param combo_source rizu.BaseScore
---@param ssf ui.formatters.ScoreSystemFormatter
function ResultStats:bind(accuracy_source, judges_source, combo_source, ssf)
	self.accuracy:setText(accuracy_source:getAccuracyString())

	local grade = ssf:getGrade(accuracy_source:getAccuracy())
	local color = ssf:getGradeColor(grade)
	self.grade:setText(grade)
	self.grade.color = color -- TODO: Label:setColor()
	self.accuracy.color = color

	local judges = judges_source:getJudges()
	local j1 = judges[1]
	local j2 = judges[2]
	local marv_perf = j1 + j2
	local other = 0
	for _, count in ipairs(judges) do
		other = other + count
	end
	other = other - marv_perf

	if j2 == 0 then
		self.ma_ratio:setText("0:0")
	elseif j1 > j2 then
		self.ma_ratio:setText(("%i:1"):format(j1 / j2))
	else
		self.ma_ratio:setText(("1:%i"):format(j2 / j1))
	end

	if other == 0 then
		self.pa_ratio:setText("0:0")
	elseif marv_perf > other then
		self.pa_ratio:setText(("%i:1"):format(marv_perf / other))
	else
		self.pa_ratio:setText(("1:%i"):format(other / marv_perf))
	end

	self.misses:setText(("%ix"):format(combo_source.missCount))
	self.numbers:fitContent()
	self:fitContent()
end

return ResultStats
