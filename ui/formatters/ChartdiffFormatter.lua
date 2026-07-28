local class = require("class")
local Color = require("ui.Color")

--- Formats info from chartdiff
--- You can get it from GameController.computeContext.chartdiff
--- It can be nil there
---@class ui.formatters.ChartdiffFormatter
---@overload fun(chartdiff: sea.Chartdiff, settings: sphere.SettingsConfig): ui.formatters.ChartdiffFormatter
local ChartdiffFormatter = class()

---@param chartdiff sea.Chartdiff?
---@param settings sphere.SettingsConfig
function ChartdiffFormatter:new(chartdiff, settings)
	self.chartdiff = chartdiff or {}
	self.settings = settings
end

---@param chartdiff sea.Chartdiff?
function ChartdiffFormatter:setChartdiff(chartdiff)
	self.chartdiff = chartdiff or {}
end

function ChartdiffFormatter:getDifficulty()
	local diff_column = self.settings.select.diff_column
	local num = self.chartdiff[diff_column] or 0

	return {
		value = ("%0.01f"):format(num),
		color = Color.diffToColor(diff_column, num, {1, 1, 1, 1})
	}
end

---@return string
function ChartdiffFormatter:getLongNoteRatio()
	return ("%i%%"):format(self.chartdiff.long_note_ratio or 0)
end

---@return string
function ChartdiffFormatter:getNoteCount()
	return tostring(self.chartdiff.notes_count or 0)
end

return ChartdiffFormatter
