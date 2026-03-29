local class = require("class")

---@class rizu.library.tasks.BatchProcessor
---@operator call: rizu.library.tasks.BatchProcessor
local BatchProcessor = class()

---@param taskContext rizu.library.ITaskContext
---@param timer time.ITimer
---@param batchSize integer?
function BatchProcessor:new(taskContext, timer, batchSize)
	self.taskContext = taskContext
	self.timer = timer
	self.batchSize = batchSize or 100
	self.reportInterval = 0.1 -- 10 updates per second
end

---@generic T
---@param items T[] | fun(): T?
---@param stage rizu.library.TaskStage
---@param total integer?
---@param processorFunc fun(item: T): string?
---@return rizu.library.TaskResult
function BatchProcessor:process(items, stage, total, processorFunc)
	local iterator
	if type(items) == "table" then
		total = total or #items
		local i = 0
		iterator = function()
			i = i + 1
			return items[i]
		end
	else
		iterator = items
	end

	self.taskContext:startStage(stage, total or 0)
	self.taskContext:dbBegin()
	
	---@type rizu.library.TaskResult
	local result = { processed = 0, errors = 0, failures = {} }
	local lastReportAt = self.timer:getTime()
	local current = 0
	
	local ok, err = xpcall(function()
		local item = iterator()
		while item do
			if self.taskContext:shouldStop() then break end
			current = current + 1

			local ok_item, label = xpcall(processorFunc, debug.traceback, item)
			if not ok_item then
				self.taskContext:addError(tostring(label))
				table.insert(result.failures, {
					item = tostring(item),
					error = tostring(label)
				})
				label = "error"
				result.errors = result.errors + 1
			else
				result.processed = result.processed + 1
			end

			self.taskContext:advance(1)
			
			local now = self.timer:getTime()
			local needsReport = (now - lastReportAt > self.reportInterval)
			local needsCommit = (current % self.batchSize == 0)

			if needsCommit then
				self.taskContext:dbCommit()
				self.taskContext:dbBegin()
			end
			
			if needsReport or needsCommit then
				self.taskContext:report(label)
				lastReportAt = now
			end
			
			item = iterator()
		end
	end, debug.traceback)

	self.taskContext:dbCommit()

	if not ok then
		print("BatchProcessor CRITICAL ERROR:", err)
		error(err)
	end
	
	self.taskContext:finish()
	
	return result
end

return BatchProcessor
