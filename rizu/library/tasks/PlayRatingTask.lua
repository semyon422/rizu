local class = require("class")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local HitsTask = require("rizu.library.tasks.HitsTask")
local CalculatorsRepo = require("rizu.library.repos.CalculatorsRepo")

---Rates the local chartplays that miss a rating of a plugin calculator, playing their replays again.
---New plays are rated when they are saved, see rizu.ScoreSaver.
---@class rizu.library.tasks.PlayRatingTask
---@operator call: rizu.library.tasks.PlayRatingTask
local PlayRatingTask = class()

---@param calculators rizu.library.Calculator[]
---@param models rdb.Models
---@param chartsRepo sea.ChartsRepo
---@param computeDataLoader sea.ComputeDataLoader
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
function PlayRatingTask:new(calculators, models, chartsRepo, computeDataLoader, taskContext, timer)
	self.calculators = calculators
	self.models = models
	self.calculatorsRepo = CalculatorsRepo(models)
	self.chartsRepo = chartsRepo
	self.computeDataLoader = computeDataLoader
	self.taskContext = taskContext
	self.batchProcessor = BatchProcessor(taskContext, timer)
end

---Plays that cannot be played again are left out, as in HitsTask: custom ones and those of charts not in the library.
function PlayRatingTask:computeMissing()
	if not self.calculators[1] then
		return
	end
	---@type sea.Chartplay[]
	local chartplays = {}
	for _, id in ipairs(self.calculatorsRepo:getChartplaysMissingRatings(self.calculators)) do
		local chartplay = self.models.chartplays:find({id = id})
		if chartplay and not chartplay.custom
			and self.chartsRepo:getChartmetaByHashIndex(chartplay.hash, chartplay.index)
		then
			table.insert(chartplays, chartplay)
		end
	end

	self.batchProcessor:process(chartplays, "scores", #chartplays, function(chartplay)
		local ok, ctx = xpcall(HitsTask.playAgain, debug.traceback, self.computeDataLoader, chartplay)
		-- A play that can't be played again is stored as not rated, so it isn't retried at every start.
		if not ok then
			self.calculatorsRepo:ratePlay(self.calculators, chartplay.id)
			error(ctx)
		end
		local errors = self.calculatorsRepo:ratePlay(self.calculators, chartplay.id, ctx.diffcalc_context, ctx.score_engine)
		for _, err in ipairs(errors) do
			self.taskContext:addError(err)
		end
		return chartplay.replay_hash
	end)
end

return PlayRatingTask
