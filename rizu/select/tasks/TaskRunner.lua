local class = require("class")
local thread = require("thread")

---@alias rizu.select.tasks.TaskFunc fun()

---@class rizu.select.tasks.TaskRunner
---@operator call: rizu.select.tasks.TaskRunner
---@field current_task_func rizu.select.tasks.TaskFunc?
---@field pending_task_func rizu.select.tasks.TaskFunc?
---@field pending_level integer?
---@field is_running boolean
local TaskRunner = class()

TaskRunner.priority = {
	high = 1,
	low = 2,
}

function TaskRunner:new()
	---@type rizu.select.tasks.TaskFunc?
	self.current_task_func = nil
	---@type rizu.select.tasks.TaskFunc?
	self.pending_task_func = nil
	---@type integer?
	self.pending_level = nil
	self.is_running = false
end

---@param task_func rizu.select.tasks.TaskFunc
---@param level integer? Lower is higher priority. Use `TaskRunner.priority`.
function TaskRunner:push(task_func, level)
	level = level or TaskRunner.priority.high
	if not self.is_running then
		self:_run(task_func, level)
	else
		-- Override pending task only if new task has higher or equal priority (lower or equal level)
		if not self.pending_level or level <= self.pending_level then
			self.pending_task_func = task_func
			self.pending_level = level
		end
	end
end

---@private
---@param self rizu.select.tasks.TaskRunner
---@param task_func rizu.select.tasks.TaskFunc
---@param level integer
local function run(self, task_func, level)
	self.is_running = true
	self.current_task_func = task_func

	-- Execute the task
	local status, err = xpcall(task_func, debug.traceback)
	if not status then
		print("TaskRunner Error: " .. tostring(err))
	end

	self.current_task_func = nil
	self.is_running = false

	-- Check if there is a pending task to run next
	if self.pending_task_func then
		local next_task = self.pending_task_func
		local next_level = self.pending_level
		self.pending_task_func = nil
		self.pending_level = nil
		self:_run(next_task, assert(next_level))
	end
end

TaskRunner._run = thread.coro(run)

return TaskRunner
