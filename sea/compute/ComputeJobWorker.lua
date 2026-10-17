local class = require("class")

---@class sea.ComputeJobWorker
---@operator call: sea.ComputeJobWorker
local ComputeJobWorker = class()

ComputeJobWorker.idle_interval = 1
ComputeJobWorker.error_interval = 5

---@param compute_jobs sea.ComputeJobs|sea.ChartplayEffects
---@param schedule fun(delay: number, callback: fun(premature: boolean)): true?, string?
---@param log fun(level: "error"|"notice", message: string)
function ComputeJobWorker:new(compute_jobs, schedule, log)
	self.compute_jobs = assert(compute_jobs)
	self.schedule = assert(schedule)
	self.log = assert(log)
	self.running = false
	self.stopped = false
end

---@param delay number
---@return true?
---@return string?
function ComputeJobWorker:scheduleNext(delay)
	local ok, err = self.schedule(delay, function(premature)
		self:tick(premature)
	end)
	if not ok then
		self.running = false
		self.log("error", "compute job worker scheduling failed: " .. tostring(err))
	end
	return ok, err
end

---@return true?
---@return string?
function ComputeJobWorker:start()
	if self.running then
		return true
	end
	self.stopped = false
	self.running = true
	return self:scheduleNext(0)
end

function ComputeJobWorker:stop()
	self.stopped = true
end

---@param premature boolean
function ComputeJobWorker:tick(premature)
	if premature or self.stopped then
		self.running = false
		return
	end

	local ok, result, failure = xpcall(function()
		return self.compute_jobs:process()
	end, debug.traceback)
	local delay = 0
	if not ok then
		self.log("error", "compute job worker crashed: " .. tostring(result))
		delay = self.error_interval
	elseif failure and (failure.code == "job_not_claimable" or failure.code == "effect_not_claimable") then
		delay = self.idle_interval
	elseif failure then
		self.log("error", ("compute job attempt failed: %s: %s"):format(failure.code, failure.message))
		delay = failure.kind == "transient" and self.error_interval or 0
	elseif result then
		self.log("notice", "compute job completed")
	end

	if not self.stopped then
		self:scheduleNext(delay)
	else
		self.running = false
	end
end

return ComputeJobWorker
