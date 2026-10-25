local class = require("class")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local ComputeContext = require("sea.compute.ComputeContext")
local StoredAccuracies = require("rizu.engine.ScoreEngine.StoredAccuracies")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---Plays every local chartplay again from its replay and stores the accuracies of the chosen systems.
---@class rizu.library.tasks.AccuracyTask
---@operator call: rizu.library.tasks.AccuracyTask
local AccuracyTask = class()

---@param chartsRepo sea.ChartsRepo
---@param accuraciesRepo rizu.library.repos.ChartplayAccuraciesRepo
---@param computeDataLoader sea.ComputeDataLoader
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
function AccuracyTask:new(chartsRepo, accuraciesRepo, computeDataLoader, taskContext, timer)
	self.chartsRepo = chartsRepo
	self.accuraciesRepo = accuraciesRepo
	self.computeDataLoader = computeDataLoader
	self.batchProcessor = BatchProcessor(taskContext, timer, 100)
end

---@param chartplay sea.Chartplay
---@param tokens string[]
---@return string label
function AccuracyTask:computeChartplay(chartplay, tokens)
	-- The server does not replay these either: their chartdiff comes from the player.
	if chartplay.custom then
		return "custom"
	end

	local chart = assert(self.computeDataLoader:requireChart(chartplay.hash))
	local replay = assert(self.computeDataLoader:requireReplay(chartplay.replay_hash)).replay

	local ctx = ComputeContext()
	assert(ctx:fromFileData(chart.name, chart.data, chartplay.index))
	ctx:applyModifierReorder(replay)
	ctx:computeBase(replay)
	assert(ctx:computeReplay(replay))

	local chartmeta = assert(ctx.chartmeta)
	local auto = Scoring(TimingSystems.getAuto(chartmeta.timings, chartmeta.format))
	self.accuraciesRepo:setAccuracies(chartplay.id, StoredAccuracies.compute(assert(ctx.score_engine), tokens, auto))

	return chartplay.replay_hash
end

---@param stored_accuracies string The scores.stored_accuracies setting.
function AccuracyTask:computeAll(stored_accuracies)
	local tokens = StoredAccuracies.parse(stored_accuracies)
	local chartplays = self.chartsRepo:getChartplays()
	print("AccuracyTask: processing chartplays", #chartplays)

	self.batchProcessor:process(chartplays, "accuracies", #chartplays, function(chartplay)
		return self:computeChartplay(chartplay, tokens)
	end)
end

return AccuracyTask
