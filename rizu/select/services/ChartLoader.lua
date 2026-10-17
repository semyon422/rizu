local class = require("class")
local ChartfileReader = require("rizu.library.ChartfileReader")
local ChartFactory = require("chart.format.notechart.ChartFactory")
local IidxDecodeContext = require("chart.format.iidx.DecodeContext")

---@class rizu.select.services.ChartLoader
---@operator call: rizu.select.services.ChartLoader
local ChartLoader = class()

---@param fs fs.IFilesystem
function ChartLoader:new(fs)
	self.fs = fs
end

---@param chartview rizu.library.LocatedChartview
---@return chart.Chart?
---@return sea.Chartmeta?
function ChartLoader:loadChart(chartview)
	local content = ChartfileReader.read(self.fs, chartview.location_path)
	if not content then
		return
	end

	local chart_chartmetas = assert(ChartFactory:getCharts(
		chartview.chartfile_name,
		content,
		nil,
		IidxDecodeContext.fromLocation(self.fs, chartview.location_prefix, chartview.chartfile_name)
	))
	local t = chart_chartmetas[chartview.index]

	return t.chart, t.chartmeta
end

---@param chartview rizu.library.LocatedChartview
---@return chart.Chart?
---@return sea.Chartmeta?
function ChartLoader:loadChartAbsolute(chartview)
	local chart, chartmeta = self:loadChart(chartview)
	if not chart then
		return
	end
	chart.layers.main:toAbsolute()
	return chart, chartmeta
end

return ChartLoader
