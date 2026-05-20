local class = require("class")

---@class chart.IChartEncoder
---@operator call: chart.IChartEncoder
local IChartEncoder = class()

---@param chart_chartmetas {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
---@return string
function IChartEncoder:encode(chart_chartmetas)
	return ""
end

return IChartEncoder
