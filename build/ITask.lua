local class = require("class")

---@class build.ITask
---@operator call: build.ITask
---@field name string
---@field deps string[]
local ITask = class()

---@param ctx build.Context
---@return any
function ITask:run(ctx)
	error("not implemented")
end

---@param ctx build.Context
---@return boolean
function ITask:upToDate(ctx)
	return false
end

---@param ctx build.Context
---@return build.StatusRow[]
function ITask:getStatus(ctx)
	return {}
end

return ITask
