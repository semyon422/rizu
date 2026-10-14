local class = require("class")
local Color = require("ui.Color")
local Settings = require("rizu.config.Settings")

--- Formats info from chartdiff
--- You can get it from `ui.api.result:getChartdiff()`
--- It can be nil there
---@class ui.formatters.ChartdiffFormatter
---@overload fun(chartdiff: rizu.api.Chartdiff, settings: rizu.config.Config): ui.formatters.ChartdiffFormatter
local ChartdiffFormatter = class()

---@param chartdiff rizu.api.Chartdiff?
---@param settings rizu.config.Config
function ChartdiffFormatter:new(chartdiff, settings)
	self.chartdiff = chartdiff or {}
	self.settings = settings
end

---@param chartdiff rizu.api.Chartdiff?
function ChartdiffFormatter:setChartdiff(chartdiff)
	self.chartdiff = chartdiff or {}
end

function ChartdiffFormatter:getDifficulty()
	local diff_column = self.settings:getChoice(Settings.keys.select.diff_column)
	local num = self.chartdiff[diff_column] or 0

	return {
		value = ("%0.01f"):format(num),
		color = Color.diffToColor(diff_column, num, {1, 1, 1, 1})
	}
end

---@return string
function ChartdiffFormatter:getLongNoteRatio()
	return ("%i%%"):format((self.chartdiff.long_notes_ratio or 0) * 100)
end

---@return string
function ChartdiffFormatter:getNoteCount()
	return tostring(self.chartdiff.notes_count or 0)
end

return ChartdiffFormatter
