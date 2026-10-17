local ComputeJobWorker = require("sea.compute.ComputeJobWorker")
local ComputeFailure = require("sea.compute.ComputeFailure")

local test = {}

local function create_ctx(responses)
	local callbacks = {}
	local delays = {}
	local logs = {}
	local index = 0
	local compute_jobs = {}
	function compute_jobs:process()
		index = index + 1
		local response = responses[index]
		if response.error then
			error(response.error)
		end
		return response.result, response.failure
	end
	local worker = ComputeJobWorker(compute_jobs, function(delay, callback)
		table.insert(delays, delay)
		table.insert(callbacks, callback)
		return true
	end, function(level, message)
		table.insert(logs, level .. ": " .. message)
	end)
	return {worker = worker, callbacks = callbacks, delays = delays, logs = logs}
end

---@param t testing.T
function test.drains_then_idles(t)
	local ctx = create_ctx({
		{result = {}},
		{failure = ComputeFailure.transient("job_not_claimable", "none")},
	})
	t:assert(ctx.worker:start())
	t:eq(ctx.delays[1], 0)
	ctx.callbacks[1](false)
	t:eq(ctx.delays[2], 0)
	ctx.callbacks[2](false)
	t:eq(ctx.delays[3], ctx.worker.idle_interval)
end

---@param t testing.T
function test.recovers_after_error(t)
	local ctx = create_ctx({{error = "boom"}})
	t:assert(ctx.worker:start())
	ctx.callbacks[1](false)
	t:eq(ctx.delays[2], ctx.worker.error_interval)
	t:assert(ctx.logs[1]:find("boom"))
end

---@param t testing.T
function test.stops_on_shutdown(t)
	local ctx = create_ctx({})
	t:assert(ctx.worker:start())
	ctx.callbacks[1](true)
	t:eq(ctx.worker.running, false)
	t:eq(#ctx.callbacks, 1)
end

return test
