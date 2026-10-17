local class = require("class")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")

---@class rizu.library.ScoreTask
---@operator call: rizu.library.ScoreTask
local ScoreTask = class()

---@param chartsRepo sea.ChartsRepo
---@param chartsComputer sea.ChartsComputer
---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
function ScoreTask:new(chartsRepo, chartsComputer, taskContext, timer)
	self.chartsRepo = chartsRepo
	self.chartsComputer = chartsComputer
	self.taskContext = taskContext
	self.batchProcessor = BatchProcessor(taskContext, timer, 100)
end

function ScoreTask:computeAll()
	local chartplays = self.chartsRepo:getChartplaysComputed(os.time(), "new", 1e6)
	print("ScoreTask: processing chartplays", #chartplays)

	self.batchProcessor:process(chartplays, "scores", #chartplays, function(chartplay)
		local ret, err = self.chartsComputer:computeChartplay(chartplay)
		if not ret then
			error("ScoreTask: " .. chartplay.replay_hash .. ": " .. tostring(err))
		end
		return chartplay.replay_hash
	end)
end

return ScoreTask
