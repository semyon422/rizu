local class = require("class")
local digest = require("digest")

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

---@class rizu.library.PreparedChartmetas
---@field chartfile sea.ClientChartfile
---@field hash string
---@field status "reused"|"cached"
---@field chart_chartmetas {chart: chart.Chart, chartmeta: sea.Chartmeta}[]?

---@param chartfile sea.ClientChartfile
---@param content string
---@param not_reuse boolean?
---@param context table?
---@return rizu.library.PreparedChartmetas?
---@return string?
function ChartmetaGenerator:prepare(chartfile, content, not_reuse, context)
	local hash = digest.hash("md5", content, true)

	local existing = self.chartsRepo:getChartmetaByHashIndex(hash, 1)
	if not not_reuse and existing and existing.mode then
		return {chartfile = chartfile, hash = hash, status = "reused"}
	end

	local chart_chartmetas, err = self.chartFactory:getCharts(chartfile.name, content, hash, context)
	if not chart_chartmetas then
		return nil, err
	end

	return {
		chartfile = chartfile,
		hash = hash,
		status = "cached",
		chart_chartmetas = chart_chartmetas,
	}
end

---@param prepared rizu.library.PreparedChartmetas
function ChartmetaGenerator:apply(prepared)
	local time = os.time()
	for _, t in ipairs(prepared.chart_chartmetas or {}) do
		self.chartsRepo:createUpdateChartmeta(t.chartmeta, time)
	end

	prepared.chartfile.hash = prepared.hash
	self.chartfilesRepo:updateChartfile(prepared.chartfile)
end

---@param chartfile sea.ClientChartfile
---@param content string
---@param not_reuse boolean?
---@param context table?
---@return string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]|string?
function ChartmetaGenerator:generate(chartfile, content, not_reuse, context)
	local prepared, err = self:prepare(chartfile, content, not_reuse, context)
	if not prepared then
		return nil, err
	end
	self:apply(prepared)
	return prepared.status, prepared.chart_chartmetas
end

return ChartmetaGenerator
