local class = require("class")

---@class build.TaskRunner
---@operator call: build.TaskRunner
---@field ctx build.Context
---@field tasks {[string]: build.ITask}
---@field completed {[string]: boolean}
local TaskRunner = class()

---@param ctx build.Context
function TaskRunner:new(ctx)
	self.ctx = ctx
	self.tasks = {}
	self.completed = {}
end

---@param task build.ITask
function TaskRunner:register(task)
	self.tasks[task.name] = task
end

---@param name string
function TaskRunner:run(name)
	if self.completed[name] then return end

	local task = self.tasks[name]
	if not task then error("Task not found: " .. name) end

	-- Run dependencies first
	if task.deps then
		for _, dep_name in ipairs(task.deps) do
			self:run(dep_name)
		end
	end

	-- Check if up-to-date
	if task.upToDate and task:upToDate(self.ctx) then
		print("Task up to date: " .. name)
	else
		print("Running task: " .. name)
		local ok, err = xpcall(function()
			task:run(self.ctx)
		end, debug.traceback)
		if not ok then
			error("Task failed: " .. name .. "\n" .. tostring(err), 0)
		end
	end

	self.completed[name] = true
end

return TaskRunner
