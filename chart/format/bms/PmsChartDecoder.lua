local ChartDecoder = require("chart.format.bms.ChartDecoder")
local Bms = require("chart.format.bms.BMS")

---@class chart.bms.PmsChartDecoder: chart.bms.ChartDecoder
---@operator call: chart.bms.PmsChartDecoder
local PmsChartDecoder = ChartDecoder + {}

---@param s string
---@param hash string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function PmsChartDecoder:decode(s, hash)
	self.hash = hash
	local bms = Bms()
	bms.pms = true
	local content = s:gsub("\r[\r\n]?", "\n")
	content = self.conv:convert(content)
	bms:import(content)
	local chart, chartmeta = self:decodeBms(bms)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

return PmsChartDecoder
