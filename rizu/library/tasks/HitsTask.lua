local class = require("class")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local ComputeContext = require("sea.compute.ComputeContext")

---Stores the hits of the local chartplays saved without them, playing their replays again,
---so the leaderboard can score them in any system, see rizu.library.repos.ChartplayHitsRepo.
---@class rizu.library.tasks.HitsTask
---@operator call: rizu.library.tasks.HitsTask
local HitsTask = class()

---@param chartsRepo sea.ChartsRepo
---@param hitsRepo rizu.library.repos.ChartplayHitsRepo
---@param computeDataLoader sea.ComputeDataLoader
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
function HitsTask:new(chartsRepo, hitsRepo, computeDataLoader, taskContext, timer)
	self.chartsRepo = chartsRepo
	self.hitsRepo = hitsRepo
	self.computeDataLoader = computeDataLoader
	self.batchProcessor = BatchProcessor(taskContext, timer)
end

---@param chartplay sea.Chartplay
---@return string label
function HitsTask:computeChartplay(chartplay)
	local chart = assert(self.computeDataLoader:requireChart(chartplay.hash))
	local replay = assert(self.computeDataLoader:requireReplay(chartplay.replay_hash)).replay

	local ctx = ComputeContext()
	assert(ctx:fromFileData(chart.name, chart.data, chartplay.index))
	ctx:applyModifierReorder(replay)
	ctx:computeBase(replay)
	assert(ctx:computeReplay(replay))

	local score_engine = assert(ctx.score_engine)
	self.hitsRepo:setHits(chartplay.id, score_engine.chartdiff, score_engine.events)

	return chartplay.replay_hash
end

---Plays that cannot be played again lack nothing: custom ones, whose chartdiff comes from
---the player, and those of charts that are not in the library.
---@return boolean completed false when the task was stopped before the last chartplay.
function HitsTask:computeMissing()
	local stored = self.hitsRepo:getStoredIds()
	---@type sea.Chartplay[]
	local chartplays = {}
	for _, chartplay in ipairs(self.chartsRepo:getChartplays()) do
		if not stored[chartplay.id] and not chartplay.custom
			and self.chartsRepo:getChartmetaByHashIndex(chartplay.hash, chartplay.index)
		then
			table.insert(chartplays, chartplay)
		end
	end
	print("HitsTask: processing chartplays", #chartplays)

	local result = self.batchProcessor:process(chartplays, "hits", #chartplays, function(chartplay)
		return self:computeChartplay(chartplay)
	end)
	return result.processed + result.errors == #chartplays
end

return HitsTask
