local IScoreProvider = require("rizu.select.IScoreProvider")

---@class rizu.select.providers.LocalScoreProvider: rizu.select.IScoreProvider
---@operator call: rizu.select.providers.LocalScoreProvider
local LocalScoreProvider = IScoreProvider + {}

---@param library rizu.library.Library
function LocalScoreProvider:new(library)
	self.library = library
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function LocalScoreProvider:getChartplaysForChartdiff(chartdiff_key)
	return self.library:getChartplaysForChartdiffAsync(chartdiff_key)
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function LocalScoreProvider:getChartplaysForChartmeta(chartmeta_key)
	return self.library:getChartplaysForChartmetaAsync(chartmeta_key)
end

return LocalScoreProvider
