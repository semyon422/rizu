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
	local num = self.chartdiff[diff_column] ---@type number?
	-- Plugin calculators rate only charts in the library, not played chartdiffs.
	if not num then
		return {value = "—", color = {1, 1, 1, 1}}
	end

	return {
		value = ("%0.01f"):format(num),
		color = Color.diffToColor(diff_column, num, {1, 1, 1, 1})
	}
end

---@return {value: string, color: gui.Color}
function ChartdiffFormatter:getLongNoteRatio()
	local notes_count = self.chartdiff.notes_count or 0
	local ratio = notes_count > 0 and ((self.chartdiff.judges_count or 0) - notes_count) / notes_count or 0
	return {
		value = ("%i%%"):format(math.floor(ratio * 100 + 0.5)),
		color = Color.lnPercentToColor(ratio, {1, 1, 1, 1})
	}
end

---@return string
function ChartdiffFormatter:getDuration()
	local duration = (self.chartdiff.duration or 0) / (self.chartdiff.rate or 1)
	return ("%i:%02i"):format(duration / 60, duration % 60)
end

---@return string
function ChartdiffFormatter:getNoteCount()
	return tostring(self.chartdiff.notes_count or 0)
end

return ChartdiffFormatter
