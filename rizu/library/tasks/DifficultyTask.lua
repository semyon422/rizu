local class = require("class")
local ModifierModel = require("sphere.models.ModifierModel")
local SphPreview = require("chart.format.sph.SphPreview")
local Sph = require("chart.format.sph.Sph")
local ChartDecoder = require("chart.format.sph.ChartDecoder")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local RizuDifficulty = require("rizu.library.RizuDifficulty")
local pattern_classifier = require("chart.scoring.pattern_classifier")

---@alias rizu.library.ChartProvider fun(hash: string): chart.Chart[]?, string?

---@class rizu.library.DifficultyTask
---@operator call: rizu.library.DifficultyTask
local DifficultyTask = class()

---@param difficultyModel chart.DifficultyModel
---@param chartdiffGenerator rizu.library.ChartdiffGenerator
---@param chartsRepo sea.ChartsRepo
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
---@param chartProvider rizu.library.ChartProvider
function DifficultyTask:new(difficultyModel, chartdiffGenerator, chartsRepo, taskContext, timer, chartProvider)
	self.difficultyModel = difficultyModel
	self.chartdiffGenerator = chartdiffGenerator
	self.chartsRepo = chartsRepo
	self.taskContext = taskContext
	self.chartProvider = chartProvider
	self.batchProcessor = BatchProcessor(taskContext, timer)
end

function DifficultyTask:computeMissing()
	local scores = self.chartsRepo:getChartplaysMissingChartdiffs()
	local chartmetas = self.chartsRepo:getChartmetasMissingChartdiffs()

	local total = #chartmetas + #scores
	local i = 0
	local iterator = function()
		i = i + 1
		if i <= #chartmetas then
			return {type = "default", data = chartmetas[i]}
		elseif i <= total then
			return {type = "modified", data = scores[i - #chartmetas]}
		end
	end

	self.batchProcessor:process(iterator, "difficulty", total, function(item)
		local data = item.data
		local charts_data, err = self.chartProvider(data.hash)
		if not charts_data then
			error("getChartsByHash error (" .. data.hash .. "): " .. tostring(err))
		end
		
		local chart = charts_data[data.index]
		local chartmeta = assert(self.chartsRepo:getChartmetaByHashIndex(data.hash, data.index))
		if chartmeta.mode ~= "mania" then
			return data.hash
		end
		chart.layers.main:toAbsolute()

		local time = os.time()
		
		if item.type == "default" then
			local chartdiff = self.chartdiffGenerator:compute(chart, 1)
			chartdiff.hash = data.hash
			chartdiff.index = data.index
			self.chartsRepo:createUpdateChartdiff(chartdiff, time)
		else
			ModifierModel:apply(data.modifiers, chart)
			local chartdiff = self.chartdiffGenerator:compute(chart, data.rate)
			chartdiff.modifiers = data.modifiers
			chartdiff.hash = data.hash
			chartdiff.index = data.index
			self.chartsRepo:createUpdateChartdiff(chartdiff, time)
		end
		
		return data.hash
	end)
end

---@param prefer_preview boolean
---@param force boolean? recompute every chartdiff, not only the incomplete ones
---@return boolean completed false when the task was stopped before the last chartdiff
function DifficultyTask:computeIncomplete(prefer_preview, force)
	local chartdiffs = force and self.chartsRepo:getChartdiffs() or self.chartsRepo:getIncompleteChartdiffs()

	local result = self.batchProcessor:process(chartdiffs, "difficulty", #chartdiffs, function(chartdiff)
		if not force then
			-- Rizu Difficulty and the pattern classifier do not rate every keymode.
			local rizu_done = chartdiff.rizu_diff or not RizuDifficulty.layouts[chartdiff.inputmode]
			local patterns_done = chartdiff.skillset or not pattern_classifier.canAnalyze(chartdiff.inputmode)
			if rizu_done and patterns_done and chartdiff.enps_diff and chartdiff.osu_diff then
				return chartdiff.hash
			end
		end
		---@type chart.Chart
		local chart

		local preview = chartdiff.notes_preview
		if preview and prefer_preview then
			local lines = SphPreview:decodeLines(preview)
			local sph = Sph()
			sph.metadata:set("input", assert(chartdiff.inputmode))
			sph.sphLines:decode(lines)

			local decoder = ChartDecoder()
			chart = decoder:decodeSph(sph)
		else
			local charts_data, err = self.chartProvider(chartdiff.hash)
			if not charts_data then
				error("getChartsByHash error (" .. chartdiff.hash .. "): " .. tostring(err))
			end
			chart = charts_data[chartdiff.index]
			chart.layers.main:toAbsolute()
			ModifierModel:apply(chartdiff.modifiers, chart)
		end

		self.difficultyModel:compute(chartdiff, chart, chartdiff.rate, force)
		self.chartsRepo:updateChartdiff(chartdiff)

		return chartdiff.hash
	end)
	return result.processed + result.errors == #chartdiffs
end

---@return boolean completed
function DifficultyTask:computeAll()
	return self:computeIncomplete(false, true)
end

return DifficultyTask
