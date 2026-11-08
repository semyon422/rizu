local class = require("class")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local pattern_classifier = require("chart.scoring.pattern_classifier")

---Classifies the charts that have no patterns yet, or patterns of an older version, from their notes preview.
---@class rizu.library.PatternTask
---@operator call: rizu.library.PatternTask
local PatternTask = class()

---@param patternsRepo rizu.library.repos.ChartPatternsRepo
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
function PatternTask:new(patternsRepo, taskContext, timer)
	self.patternsRepo = patternsRepo
	self.batchProcessor = BatchProcessor(taskContext, timer)
end

function PatternTask:computeMissing()
	-- Keymodes the classifier has no model for would stay missing and be read again at every start.
	local items = {} ---@type sea.Chartdiff[]
	for _, chartdiff in ipairs(self.patternsRepo:getMissingChartdiffs()) do
		if pattern_classifier.canAnalyze(chartdiff.inputmode) then
			table.insert(items, chartdiff)
		end
	end
	if not items[1] then
		return
	end

	self.batchProcessor:process(items, "patterns", #items, function(chartdiff)
		self.patternsRepo:save(chartdiff)
		return chartdiff.hash
	end)
end

return PatternTask
