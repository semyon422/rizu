local class = require("class")

---@class rizu.library.ChartdiffGenerator
---@operator call: rizu.library.ChartdiffGenerator
local ChartdiffGenerator = class()

---@param chartsRepo sea.ChartsRepo
---@param difficultyModel chart.DifficultyModel
function ChartdiffGenerator:new(chartsRepo, difficultyModel)
	self.chartsRepo = chartsRepo
	self.difficultyModel = difficultyModel
end

---@param chart chart.Chart
---@param rate number
function ChartdiffGenerator:compute(chart, rate)
	local chartdiff = {
		rate = rate,
		inputmode = tostring(chart.inputMode),
		modifiers = {},
		mode = "mania",
	}

	self.difficultyModel:compute(chartdiff, chart, rate)

	return chartdiff
end

---@param chart chart.Chart
---@param hash string
---@param index number
---@return sea.Chartdiff?
---@return string?
function ChartdiffGenerator:create(chart, hash, index)
	local chartdiff = self.chartsRepo:selectDefaultChartdiff(hash, index)
	if chartdiff then
		return chartdiff
	end

	local ok, chartdiff = xpcall(self.compute, debug.traceback, self, chart, 1)
	if not ok then
		---@cast chartdiff +string, -table
		return nil, chartdiff
	end

	chartdiff.hash = hash
	chartdiff.index = index

	self.chartsRepo:createUpdateChartdiff(chartdiff, os.time())

	return chartdiff
end

return ChartdiffGenerator
