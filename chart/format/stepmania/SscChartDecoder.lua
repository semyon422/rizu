local ChartDecoder = require("chart.format.stepmania.ChartDecoder")
local Ssc = require("chart.format.stepmania.Ssc")

---@class chart.stepmania.SscChartDecoder: chart.stepmania.ChartDecoder
---@operator call: chart.stepmania.SscChartDecoder
local SscChartDecoder = ChartDecoder + {}

---@param s string
---@return chart.Chart[]
function SscChartDecoder:decode(s)
	local ssc = Ssc()
	s = self.conv:convert(s)
	ssc:decode(s)

	---@type {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
	local charts = {}
	for i = 1, #ssc.charts do
		local chart, chartmeta = self:decodeSm(ssc, i)
		charts[i] = {
			chart = chart,
			chartmeta = chartmeta,
		}
	end
	return charts
end

return SscChartDecoder
