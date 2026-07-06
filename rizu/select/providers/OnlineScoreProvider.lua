local IScoreProvider = require("rizu.select.IScoreProvider")
local ChartdiffKey = require("sea.chart.ChartdiffKey")
local ChartmetaKey = require("sea.chart.ChartmetaKey")

---@class rizu.select.providers.OnlineScoreProvider: rizu.select.IScoreProvider
---@operator call: rizu.select.providers.OnlineScoreProvider
local OnlineScoreProvider = IScoreProvider + {}

---@param onlineModel rizu.OnlineModel
function OnlineScoreProvider:new(onlineModel)
	self.onlineModel = onlineModel
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function OnlineScoreProvider:getChartplaysForChartdiff(chartdiff_key)
	local sea_client = self.onlineModel.authManager.sea_client
	if not sea_client.connected then
		return {}
	end

	local key = ChartdiffKey()
	key:importChartdiffKey(chartdiff_key)
	return sea_client.remote.submission:getBestChartplaysForChartdiff(key) or {}
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function OnlineScoreProvider:getChartplaysForChartmeta(chartmeta_key)
	local sea_client = self.onlineModel.authManager.sea_client
	if not sea_client.connected then
		return {}
	end

	local key = ChartmetaKey()
	key:importChartmetaKey(chartmeta_key)
	return sea_client.remote.submission:getBestChartplaysForChartmeta(key) or {}
end

return OnlineScoreProvider
