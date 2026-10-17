local class = require("class")

---@class rizu.library.Status
---@operator call: rizu.library.Status
local Status = class()

---@param chartfilesRepo rizu.library.ChartfilesRepo
---@param chartsRepo sea.ChartsRepo
function Status:new(chartfilesRepo, chartsRepo)
	self.chartfilesRepo = chartfilesRepo
	self.chartsRepo = chartsRepo
end

function Status:update()
	self.chartfile_sets = self.chartfilesRepo:countChartfileSets()
	self.chartfiles_count = self.chartfilesRepo:countChartfiles()
	self.chartmetas = self.chartsRepo:countChartmetas()
	self.chartdiffs = self.chartsRepo:countChartdiffs()
	self.chartplays = self.chartsRepo:countChartplays()
end

return Status
