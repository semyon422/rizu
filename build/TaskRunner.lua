local class = require("class")

---@class build.Task
---@field name string
---@field deps string[]
---@field run fun(ctx: build.Context)
---@field upToDate fun(ctx: build.Context): boolean

---@class build.TaskRunner
---@field ctx build.Context
---@field tasks {[string]: build.Task}
local TaskRunner = class()

---@param ctx build.Context
function TaskRunner:new(ctx)
	self.ctx = ctx
	self.tasks = {}
	self.completed = {}
end

---@param task build.Task
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
		task:run(self.ctx)
	end
	
	self.completed[name] = true
end

return TaskRunner
