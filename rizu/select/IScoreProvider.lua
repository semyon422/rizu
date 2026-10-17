local class = require("class")

---@class rizu.select.IScoreProvider
---@operator call: rizu.select.IScoreProvider
local IScoreProvider = class()

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function IScoreProvider:getChartplaysForChartdiff(chartdiff_key)
	error("not implemented")
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function IScoreProvider:getChartplaysForChartmeta(chartmeta_key)
	error("not implemented")
end

return IScoreProvider
