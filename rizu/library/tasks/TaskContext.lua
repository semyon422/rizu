local ITaskContext = require("rizu.library.tasks.ITaskContext")

---@class rizu.library.TaskContext: rizu.library.ITaskContext
---@operator call: rizu.library.TaskContext
local TaskContext = ITaskContext + {}

function TaskContext:new(libraryProcessor)
	self.libraryProcessor = libraryProcessor
	self.errorCount = 0
	self.current = 0
	self.total = 0
	self.stage = "idle"
end

function TaskContext:getChartsByHash(hash)
	return self.libraryProcessor:getChartsByHash(hash)
end

function TaskContext:startStage(stage, total)
	self.stage = stage
	self.total = total
	self.current = 0
	self:report()
end

function TaskContext:advance(amount, label)
	self.current = self.current + (amount or 1)
end

function TaskContext:report(label)
	self.libraryProcessor.stage = self.stage
	self.libraryProcessor.chartfiles_count = self.total
	self.libraryProcessor.chartfiles_current = self.current
	self.libraryProcessor.stage_label = label
	self.libraryProcessor.errorCount = self.errorCount
	self.libraryProcessor:checkProgress()
end

function TaskContext:finish()
	self.current = self.total
	self.stage = "idle"
	self:report()
end

function TaskContext:checkProgress(stage, data)
	self.stage = stage
	self.total = data.total
	self.current = data.current
	self:report(data.label)
end

function TaskContext:shouldStop()
	self.libraryProcessor:checkProgress()
	return self.libraryProcessor.needStop == true
end

function TaskContext:addError(err)
	self.errorCount = self.errorCount + 1
	self.libraryProcessor:addError(err)
end

function TaskContext:dbBegin()
	self.libraryProcessor:begin()
end

function TaskContext:dbCommit()
	self.libraryProcessor:commit()
end

return TaskContext
