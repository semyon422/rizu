local class = require("class")
local path_util = require("path_util")
local ChartFactory = require("chart.format.notechart.ChartFactory")

---@class rizu.select.services.ChartMetadataService
---@operator call: rizu.select.services.ChartMetadataService
local ChartMetadataService = class()

---@param fs fs.IFilesystem
function ChartMetadataService:new(fs)
	self.fs = fs
end

---@param chartview rizu.library.LocatedChartview
---@return string?
function ChartMetadataService:getBackgroundPath(chartview)
	local name = chartview.chartfile_name
	if name:find("%.ojn$") or name:find("%.mid$") then
		return chartview.location_path
	end

	local background_path = chartview.background_path
	if not background_path or background_path == "" then
		return chartview.location_dir
	end

	return path_util.join(chartview.location_dir, background_path)
end

---@param chartview rizu.library.LocatedChartview
---@return string? full_path
---@return number? preview_time
---@return string? mode
function ChartMetadataService:getAudioPathPreview(chartview)
	local mode = "absolute"

	local audio_path = chartview.audio_path
	if not audio_path or audio_path == "" then
		return "", 0.4, "relative"
	end

	local full_path = path_util.join(chartview.real_dir, audio_path)
	local preview_time = chartview.preview_time

	local format = chartview.format
	if preview_time < 0 and (format == "osu" or format == "qua") then
		mode = "relative"
		preview_time = 0.4
	end

	return full_path, preview_time, mode
end

---@param chartview rizu.library.LocatedChartview
---@return chart.Chart?
---@return sea.Chartmeta?
function ChartMetadataService:loadChart(chartview)
	local content = self.fs:read(chartview.location_path)
	if not content then
		return
	end

	local chart_chartmetas = assert(ChartFactory:getCharts(
		chartview.chartfile_name,
		content
	))
	local t = chart_chartmetas[chartview.index]

	return t.chart, t.chartmeta
end

---@param chartview rizu.library.LocatedChartview
---@return chart.Chart?
---@return sea.Chartmeta?
function ChartMetadataService:loadChartAbsolute(chartview)
	local chart, chartmeta = self:loadChart(chartview)
	if not chart then
		return
	end
	chart.layers.main:toAbsolute()
	return chart, chartmeta
end

return ChartMetadataService
