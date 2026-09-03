local class = require("class")
local Color = require("ui.Color")
local MsdFormatter = require("ui.formatters.MsdFormatter")
local Settings = require("rizu.config.Settings")

--- Formats info from chartview
--- You can get it from GameController.chartSelector.chartview
---@class ui.formatters.ChartviewFormatter
---@overload fun(chartview: rizu.library.LocatedChartview, settings: rizu.config.Config): ui.formatters.ChartviewFormatter
local ChartviewFormatter = class()

---@param chartview rizu.library.LocatedChartview?
---@param settings rizu.config.Config
function ChartviewFormatter:new(chartview, settings)
	self.chartview = chartview or {}
	self.settings = settings
	self.time_rate = 1
end

---@param chartview rizu.library.LocatedChartview?
function ChartviewFormatter:setChartview(chartview)
	self.chartview = chartview or {}
end

---@param time_rate number
function ChartviewFormatter:setTimeRate(time_rate)
	self.time_rate = time_rate
end

---@return {value: string, color: gui.Color}
function ChartviewFormatter:getTimeRate()
	return {
		value = ("%0.02fx"):format(self.time_rate),
		color = Color.linearRateToColor(self.time_rate, {1, 1, 1, 1})
	}
end

---@return {value: string, postfix: string, color: gui.Color}
function ChartviewFormatter:getDifficulty()
	local diff_column = self.settings:getChoice(Settings.keys.select.diff_column)
	local num = self.chartview[diff_column] or 0

	local postfix = "?"

	if diff_column == "osu_diff" then
		postfix = "OSU!SR"
	elseif diff_column == "msd_diff" then
		postfix = "MSD"
	elseif diff_column == "enps_diff" then
		postfix = "ENPS"
	end

	return {
		value = ("%0.01f"):format(num),
		postfix = postfix,
		color = Color.diffToColor(diff_column, num, {1, 1, 1, 1})
	}
end

---@return {top_full: string?, second_full: string?, top_simple: string?, second_simple: string?}
function ChartviewFormatter:getPatterns()
	local msd_diff_data = self.chartview.msd_diff_data
	local msd_diff_rates = self.chartview.msd_diff_rates

	if not msd_diff_data or not msd_diff_rates then
		return {}
	end

	local msd_formatter = MsdFormatter(msd_diff_data, msd_diff_rates)
	local first, second = msd_formatter:getTopPatterns(self.time_rate)

	local t = {
		top_full = first,
		second_full = second,
	}

	if first then
		t.top_simple = msd_formatter.simplifyName(first)
	end

	if second then
		t.second_simple = msd_formatter.simplifyName(second)
	end

	return t
end

---@return string
function ChartviewFormatter:getDuration()
	local duration = (self.chartview.duration or 0) / self.time_rate
	return ("%i:%02i"):format(duration / 60, duration % 60)
end

---@return {value: string, color: gui.Color}
function ChartviewFormatter:getLongNoteRatio()
	local ratio = self.chartview.long_notes_ratio or 0
	return {
		value = ("%i%%"):format(math.floor(ratio * 100 + 0.5)),
		color = Color.lnPercentToColor(ratio, {1, 1, 1, 1})
	}
end

---@return {min: string, max: string, avg: string}
function ChartviewFormatter:getTempo()
	return {
		avg = ("%i"):format(self.chartview.tempo or 0), -- SHOULD USE chartview.tempo_avg, but it's always 0
		min = ("%i"):format(self.chartview.tempo_min or 0),
		max = ("%i"):format(self.chartview.tempo_max or 0)
	}
end

---@return string
function ChartviewFormatter:getNoteCount()
	return tostring(self.chartview.notes_count or 0)
end

---@return string
function ChartviewFormatter:getMode()
	local chartview = self.chartview
	local inputmode = chartview.chartdiff_inputmode or chartview.inputmode
	if inputmode and inputmode ~= "" then
		return inputmode:gsub("key", "K"):gsub("scratch", "S"):upper()
	end
	if chartview.mode and chartview.mode ~= "" then
		return chartview.mode:upper()
	end
	return "NO CHART"
end

---@return string
function ChartviewFormatter:getLevel()
	return tostring(self.chartview.level or 0)
end

---@return string
function ChartviewFormatter:getFormat()
	return (self.chartview.format or "unknown"):upper()
end

---@return string
function ChartviewFormatter:getTitle()
	local cv = self.chartview
	return cv.title and not cv.title:match("^%s*$") and cv.title or "Unknown title"
end

---@return string
function ChartviewFormatter:getArtist()
	local cv = self.chartview
	return cv.artist and not cv.artist:match("^%s*$") and cv.artist or "Unknown artist"
end

---@return boolean
function ChartviewFormatter:isRanked()
	return self.chartview.difftable_chartmetas and #self.chartview.difftable_chartmetas > 0 or false
end

return ChartviewFormatter
