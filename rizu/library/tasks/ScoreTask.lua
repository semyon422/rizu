local class = require("class")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")

---@class rizu.library.ScoreTask
---@operator call: rizu.library.ScoreTask
local ScoreTask = class()

---Bump it to compute every local score again at the next start after an update, see Library:updateScores().
ScoreTask.version = 3

---@param chartsRepo sea.ChartsRepo
---@param chartsComputer sea.ChartsComputer
---@param hitsRepo rizu.library.repos.ChartplayHitsRepo
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
function ScoreTask:new(chartsRepo, chartsComputer, hitsRepo, taskContext, timer)
	self.chartsRepo = chartsRepo
	self.chartsComputer = chartsComputer
	self.hitsRepo = hitsRepo
	self.taskContext = taskContext
	self.batchProcessor = BatchProcessor(taskContext, timer)
end

---@param chartplays sea.Chartplay[]
---@return boolean completed false when the task was stopped before the last chartplay.
function ScoreTask:compute(chartplays)
	print("ScoreTask: processing chartplays", #chartplays)

	local result = self.batchProcessor:process(chartplays, "scores", #chartplays, function(chartplay)
		local ret, err = self.chartsComputer:computeChartplay(chartplay)
		if not ret then
			error("ScoreTask: " .. chartplay.replay_hash .. ": " .. tostring(err))
		end
		local score_engine = ret.score_engine
		if score_engine then
			self.hitsRepo:setHits(chartplay.id, score_engine.chart_info, score_engine.events)
		end
		return chartplay.replay_hash
	end)
	return result.processed + result.errors == #chartplays
end

function ScoreTask:computeAll()
	self:compute(self.chartsRepo:getChartplaysComputed(os.time(), "new", 1e6))
end

---Every chartplay again, however long ago it was computed: its rating, accuracy and hits.
---Custom plays and plays of charts not in the library cannot be played again, see HitsTask.
---@param since integer? Only the chartplays computed before it, so a stopped run goes on where it stopped.
---@return boolean completed
function ScoreTask:recomputeAll(since)
	---@type sea.Chartplay[]
	local chartplays = {}
	for _, chartplay in ipairs(self.chartsRepo:getChartplays()) do
		if not chartplay.custom and (not since or chartplay.computed_at < since)
			and self.chartsRepo:getChartmetaByHashIndex(chartplay.hash, chartplay.index)
		then
			table.insert(chartplays, chartplay)
		end
	end
	return self:compute(chartplays)
end

return ScoreTask
