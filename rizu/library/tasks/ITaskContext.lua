local class = require("class")

---@alias rizu.library.TaskStage "idle"|"scanning"|"hashing"|"difficulty"|"scores"

---@class rizu.library.TaskStatus
---@field stage rizu.library.TaskStage
---@field current integer
---@field total integer
---@field label string?
---@field errorCount integer
---@field itemsPerSecond number?
---@field eta number?

---@class rizu.library.TaskFailure
---@field item string
---@field error string
---@field type string?

---@class rizu.library.TaskResult
---@field processed integer
---@field errors integer
---@field failures rizu.library.TaskFailure[]

---@class rizu.library.ITaskContext
---@operator call: rizu.library.ITaskContext
local ITaskContext = class()

---@param hash string
---@return chart.Chart[]?
---@return string?
function ITaskContext:getChartsByHash(hash)
	error("not implemented")
end

---@param stage rizu.library.TaskStage
---@param total integer
function ITaskContext:startStage(stage, total)
	error("not implemented")
end

---@param amount integer
---@param label string?
function ITaskContext:advance(amount, label)
	error("not implemented")
end

---@param label string?
function ITaskContext:report(label)
	error("not implemented")
end

function ITaskContext:finish()
	error("not implemented")
end

---@param stage rizu.library.TaskStage
---@param data {current: integer, total: integer, label: string?}
function ITaskContext:checkProgress(stage, data)
	error("not implemented")
end

---@return boolean
function ITaskContext:shouldStop()
	error("not implemented")
end

---@param err any
function ITaskContext:addError(err)
	error("not implemented")
end

function ITaskContext:dbBegin()
	error("not implemented")
end

function ITaskContext:dbCommit()
	error("not implemented")
end

return ITaskContext
