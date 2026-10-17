local TaskRunner = require("rizu.select.tasks.TaskRunner")

local test = {}
local priority = TaskRunner.priority
local very_low_priority = priority.low + 1

---@param t testing.T
function test.runs_immediately_when_idle(t)
	local runner = TaskRunner()
	---@type string[]
	local events = {}

	runner:push(function()
		table.insert(events, "run")
	end, priority.high)

	t:tdeq(events, {"run"})
	t:eq(runner.is_running, false)
end

---@param t testing.T
function test.pending_task_waits_until_current_finishes(t)
	local runner = TaskRunner()
	---@type string[]
	local events = {}
	---@type thread
	local current_co

	runner:push(function()
		table.insert(events, "current-start")
		current_co = coroutine.running()
		coroutine.yield()
		table.insert(events, "current-end")
	end, priority.high)

	runner:push(function()
		table.insert(events, "pending")
	end, priority.high)

	t:tdeq(events, {"current-start"})

	coroutine.resume(current_co)

	t:tdeq(events, {"current-start", "current-end", "pending"})
	t:eq(runner.is_running, false)
end

---@param t testing.T
function test.lower_priority_does_not_override_pending_task(t)
	local runner = TaskRunner()
	---@type string[]
	local events = {}
	---@type thread
	local current_co

	runner:push(function()
		table.insert(events, "current-start")
		current_co = coroutine.running()
		coroutine.yield()
		table.insert(events, "current-end")
	end, priority.high)

	runner:push(function()
		table.insert(events, "pending-low")
	end, priority.low)
	runner:push(function()
		table.insert(events, "pending-very-low")
	end, very_low_priority)

	coroutine.resume(current_co)

	t:tdeq(events, {"current-start", "current-end", "pending-low"})
end

---@param t testing.T
function test.equal_or_higher_priority_overrides_pending_task(t)
	local runner = TaskRunner()
	---@type string[]
	local events = {}
	---@type thread
	local current_co

	runner:push(function()
		table.insert(events, "current-start")
		current_co = coroutine.running()
		coroutine.yield()
		table.insert(events, "current-end")
	end, priority.high)

	runner:push(function()
		table.insert(events, "pending-very-low")
	end, very_low_priority)
	runner:push(function()
		table.insert(events, "pending-low-a")
	end, priority.low)
	runner:push(function()
		table.insert(events, "pending-low-b")
	end, priority.low)

	coroutine.resume(current_co)

	t:tdeq(events, {"current-start", "current-end", "pending-low-b"})
end

return test
