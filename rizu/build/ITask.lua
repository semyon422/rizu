local class = require("class")

---@class rizu.build.ITask
---@operator call: rizu.build.ITask
---@field name string
---@field deps string[]
local ITask = class()

---@param ctx rizu.build.Context
---@return any
function ITask:run(ctx)
	error("not implemented")
end

---@param ctx rizu.build.Context
---@return boolean
function ITask:upToDate(ctx)
	return false
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function ITask:getStatus(ctx)
	return {}
end

return ITask
