local class = require("class")
local md5 = require("md5")

---@class rizu.library.ChartmetaGenerator
---@operator call: rizu.library.ChartmetaGenerator
local ChartmetaGenerator = class()

---@param chartsRepo sea.ChartsRepo
---@param chartfilesRepo rizu.library.ChartfilesRepo
---@param chartFactory chart.ChartFactory
function ChartmetaGenerator:new(chartsRepo, chartfilesRepo, chartFactory)
	self.chartsRepo = chartsRepo
	self.chartfilesRepo = chartfilesRepo
	self.chartFactory = chartFactory
end

---@param chartfile sea.ClientChartfile
---@param content string
---@param not_reuse boolean?
---@param context table?
---@return string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]|string?
function ChartmetaGenerator:generate(chartfile, content, not_reuse, context)
	local chartfilesRepo = self.chartfilesRepo
	local chartsRepo = self.chartsRepo

	local hash = md5.sumhexa(content)

	if not not_reuse and chartsRepo:getChartmetaByHashIndex(hash, 1) then
		chartfile.hash = hash
		chartfilesRepo:updateChartfile(chartfile)
		return "reused"
	end

	local chart_chartmetas, err = self.chartFactory:getCharts(chartfile.name, content, hash, context)
	if not chart_chartmetas then
		return nil, err
	end

	local time = os.time()
	for _, t in ipairs(chart_chartmetas) do
		chartsRepo:createUpdateChartmeta(t.chartmeta, time)
	end

	chartfile.hash = hash
	chartfilesRepo:updateChartfile(chartfile)

	return "cached", chart_chartmetas
end

return ChartmetaGenerator
