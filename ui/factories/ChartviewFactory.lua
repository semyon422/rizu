local class = require("class")
local Color = require("ui.Color")
local MsdFactory = require("ui.factories.MsdFactory")

--- Formats info from chartview
--- You can get it from GameController.chartSelector.chartview
---@class ui.factories.ChartviewFactory
---@overload fun(chartview: rizu.library.LocatedChartview, settings: sphere.SettingsConfig): ui.factories.ChartviewFactory
local ChartviewFactory = class()

---@param chartview rizu.library.LocatedChartview?
---@param settings sphere.SettingsConfig
function ChartviewFactory:new(chartview, settings)
	self.chartview = chartview or {}
	self.settings = settings
	self.time_rate = 1
end

---@param chartview rizu.library.LocatedChartview?
function ChartviewFactory:setChartview(chartview)
	self.chartview = chartview or {}
end

---@param time_rate number
function ChartviewFactory:setTimeRate(time_rate)
	self.time_rate = time_rate
end

---@return {value: string, color: gui.Color}
function ChartviewFactory:getTimeRate()
	return {
		value = ("%0.02fx"):format(self.time_rate),
		color = Color.linearRateToColor(self.time_rate, {1, 1, 1, 1})
	}
end

---@return {value: string, color: gui.Color}
function ChartviewFactory:getDifficulty()
	local diff_column = self.settings.select.diff_column
	local num = self.chartview[diff_column] or 0

	return {
		value = ("%0.01f"):format(num),
		color = Color.diffToColor(diff_column, num, {1, 1, 1, 1})
	}
end

---@return {top_full: string?, second_full: string?, top_simple: string?, second_simple: string?}
function ChartviewFactory:getPatterns()
	local msd_diff_data = self.chartview.msd_diff_data
	local msd_diff_rates = self.chartview.msd_diff_rates

	if not msd_diff_data or not msd_diff_rates then
		return {}
	end

	local msd_factory = MsdFactory(msd_diff_data, msd_diff_rates)
	local first, second = msd_factory:getTopPatterns(self.time_rate)

	local t = {
		top_full = first,
		second_full = second,
	}

	if first then
		t.top_simple = msd_factory.simplifyName(first)
	end

	if second then
		t.second_simple = msd_factory.simplifyName(second)
	end

	return t
end

---@return string
function ChartviewFactory:getDuration()
	local duration = (self.chartview.duration or 0) / self.time_rate
	return ("%i:%02i"):format(duration / 60, duration % 60)
end

---@return {value: string, color: gui.Color}
function ChartviewFactory:getLongNoteRatio()
	local ratio = self.chartview.long_notes_ratio or 0
	return {
		value = ("%i%%"):format(ratio),
		color = Color.lnPercentToColor(ratio, {1, 1, 1, 1})
	}
end

---@return {min: string, max: string, avg: string}
function ChartviewFactory:getTempo()
	return {
		avg = ("%i"):format(self.chartview.tempo or 0), -- SHOULD USE chartview.tempo_avg, but it's always 0
		min = ("%i"):format(self.chartview.tempo_min or 0),
		max = ("%i"):format(self.chartview.tempo_max or 0)
	}
end

---@return string
function ChartviewFactory:getNoteCount()
	return tostring(self.chartview.notes_count or 0)
end

---@return string
function ChartviewFactory:getTitle()
	local cv = self.chartview
	return cv.title and not cv.title:match("^%s*$") and cv.title or "Unknown title"
end

---@return string
function ChartviewFactory:getArtist()
	local cv = self.chartview
	return cv.artist and not cv.artist:match("^%s*$") and cv.artist or "Unknown artist"
end

---@return boolean
function ChartviewFactory:isRanked()
	return self.chartview.difftable_chartmetas and #self.chartview.difftable_chartmetas > 0 or false
end

return ChartviewFactory
