local class = require("class")
local table_util = require("table_util")
local ComputeFailure = require("sea.compute.ComputeFailure")
local ComputeJob = require("sea.compute.ComputeJob")
local ComputeRequest = require("sea.compute.ComputeRequest")
local ComputeJobStatus = require("sea.compute.ComputeJobStatus")
local Chartplay = require("sea.chart.Chartplay")
local Chartfile = require("sea.chart.Chartfile")

---@class sea.ComputeJobs
---@operator call: sea.ComputeJobs
local ComputeJobs = class()

ComputeJobs.lease_duration = 180
ComputeJobs.retry_delay = 5
ComputeJobs.max_attempts = 3

---@param compute_jobs_repo sea.ComputeJobsRepo
---@param charts_repo sea.ChartsRepo
---@param chartfiles_repo sea.ChartfilesRepo
---@param compute_data_provider sea.IComputeDataProvider
---@param replay_computer sea.IReplayComputer
---@param compute_version string
---@param transaction fun(f: function, ...: any): ...any
function ComputeJobs:new(
	compute_jobs_repo,
	charts_repo,
	chartfiles_repo,
	compute_data_provider,
	replay_computer,
	compute_version,
	transaction
)
	self.compute_jobs_repo = compute_jobs_repo
	self.charts_repo = charts_repo
	self.chartfiles_repo = chartfiles_repo
	self.compute_data_provider = compute_data_provider
	self.replay_computer = replay_computer
	self.compute_version = compute_version
	self.transaction = transaction
	self.worker_id = ("server:%d:%s"):format(os.time(), tostring({}):match("0x(.+)") or "worker")
	self.claim_index = 0
end

---@param chartplay sea.Chartplay
---@param chartdiff sea.Chartdiff
---@param time integer
---@return sea.ComputeJob
function ComputeJobs:getOrCreateJob(chartplay, chartdiff, time)
	local repo = self.compute_jobs_repo
	local job = repo:getComputeJobByChartplayId(assert(chartplay.id))
	if job then
		if chartplay.custom then
			assert(job.chartdiff:equalsComputed(chartdiff), "submitted custom chartdiff differs")
		end
		return job
	end

	job = ComputeJob()
	job.chartplay_id = chartplay.id
	job.idempotency_key = chartplay.replay_hash
	job.state = "queued"
	job.attempt_count = 0
	job.max_attempts = self.max_attempts
	job.created_at = time
	job.updated_at = time
	job.next_attempt_at = time
	job.compute_version = self.compute_version
	job.chartdiff = chartdiff
	return repo:createComputeJob(job)
end

---@param user_id integer
---@param time integer
---@param chartplay_values sea.Chartplay
---@param chartdiff sea.Chartdiff
---@param chart_name string
---@param chart_size integer
---@return sea.Chartplay
---@return sea.ComputeJob
---@return boolean duplicate
function ComputeJobs:createSubmission(user_id, time, chartplay_values, chartdiff, chart_name, chart_size)
	return self.transaction(function()
		local chartfile = self.chartfiles_repo:getChartfileByHash(chartplay_values.hash)
		if not chartfile then
			chartfile = Chartfile()
			chartfile.hash = chartplay_values.hash
			chartfile.creator_id = user_id
			chartfile.compute_state = "new"
			chartfile.computed_at = time
			chartfile.submitted_at = time
			chartfile.name = chart_name
			chartfile.size = chart_size
			self.chartfiles_repo:createChartfile(chartfile)
		end

		local chartplay = self.charts_repo:getChartplayByReplayHash(chartplay_values.replay_hash)
		local duplicate = chartplay ~= nil
		if not chartplay then
			assert(not chartplay_values.id)
			chartplay_values.user_id = user_id
			chartplay_values.submitted_at = time
			chartplay_values.computed_at = time
			chartplay_values.compute_state = "new"
			chartplay = self.charts_repo:createChartplay(chartplay_values)
		end
		assert(chartplay_values:equalsChartplay(chartplay))
		local job = self:getOrCreateJob(chartplay, chartdiff, time)
		return chartplay, job, duplicate
	end)
end

---@param job sea.ComputeJob
---@param chartplay sea.Chartplay
---@return sea.ComputeRequest?
---@return sea.ComputeFailure?
function ComputeJobs:createRequest(job, chartplay)
	local chartfile = self.chartfiles_repo:getChartfileByHash(chartplay.hash)
	if not chartfile then
		return nil, ComputeFailure.transient("chartfile_missing", "chartfile row is missing")
	end
	local chart_data, err = self.compute_data_provider:getChartData(chartplay.hash)
	if not chart_data then
		return nil, ComputeFailure.transient("chart_unavailable", tostring(err))
	end
	local replay_data
	replay_data, err = self.compute_data_provider:getReplayData(chartplay.replay_hash)
	if not replay_data then
		return nil, ComputeFailure.transient("replay_unavailable", tostring(err))
	end

	local compute_chartplay = setmetatable(table_util.sub(chartplay, table_util.keys(Chartplay.struct)), Chartplay)
	---@type sea.ComputeRequest
	local request = {
		version = job.compute_version,
		chartplay = compute_chartplay,
		chartdiff = job.chartdiff,
		chart_name = chartfile.name,
		chart_data = chart_data.data,
		replay_data = replay_data,
	}
	local ok
	ok, err = ComputeRequest.validate(request)
	if not ok then
		return nil, ComputeFailure.permanent("invalid_request", tostring(err))
	end
	return request
end

---@param job sea.ComputeJob
---@param chartplay sea.Chartplay
---@param result sea.ComputeResult
---@param lease_owner string
---@param time integer
---@return true?
---@return sea.ComputeFailure?
function ComputeJobs:finalize(job, chartplay, result, lease_owner, time)
	local now = os.time()
	if job.lease_expires_at and job.lease_expires_at <= now then
		return nil, ComputeFailure.transient("lease_expired", "compute job lease expired before finalization")
	end
	local ok, err = xpcall(self.transaction, debug.traceback, function()
		local claimed_job = self.compute_jobs_repo:getComputeJob(assert(job.id))
		assert(claimed_job and claimed_job.state == "running" and claimed_job.lease_owner == lease_owner,
			"compute job lease lost")

		local charts_repo = self.charts_repo
		charts_repo:createUpdateChartmeta(result.chartmeta, time)
		if result.default_chartdiff then
			charts_repo:createUpdateChartdiff(result.default_chartdiff, time)
		end
		if chartplay.custom then
			result.chartdiff.custom_user_id = chartplay.user_id
		else
			chartplay:importChartplayComputed(assert(result.chartplay_computed))
		end
		charts_repo:createUpdateChartdiff(result.chartdiff, time)
		chartplay.compute_state = "valid"
		chartplay.computed_at = time
		charts_repo:updateChartplay(chartplay)
		assert(self.compute_jobs_repo:succeedComputeJob(job, lease_owner, time, result.timings), "compute job lease lost")
	end)
	if not ok then
		return nil, ComputeFailure.transient("finalization_failed", tostring(err))
	end
	return true
end

---@param job sea.ComputeJob
---@param chartplay sea.Chartplay
---@param failure sea.ComputeFailure
---@param lease_owner string
---@param time integer
function ComputeJobs:recordFailure(job, chartplay, failure, lease_owner, time)
	if failure.kind == "permanent" then
		self.transaction(function()
			chartplay.compute_state = "invalid"
			chartplay.computed_at = time
			self.charts_repo:updateChartplay(chartplay)
			assert(self.compute_jobs_repo:failComputeJob(job, lease_owner, time, failure), "compute job lease lost")
		end)
		return
	end
	assert(self.compute_jobs_repo:retryComputeJob(job, lease_owner, time, failure, self.retry_delay),
		"compute job lease lost")
end

---@param user_id integer
---@param id integer
---@return sea.ComputeJobStatus?
---@return string?
function ComputeJobs:getStatus(user_id, id)
	local job = self.compute_jobs_repo:getComputeJob(id)
	if not job then
		return nil, "compute job not found"
	end
	local chartplay = self.charts_repo:getChartplay(job.chartplay_id)
	if not chartplay or chartplay.user_id ~= user_id then
		return nil, "compute job not found"
	end
	return ComputeJobStatus.create(job, job.state == "succeeded" and chartplay or nil)
end

---@param state sea.ComputeJobState?
---@param limit integer?
---@return sea.ComputeJob[]
function ComputeJobs:getJobs(state, limit)
	return self.compute_jobs_repo:getComputeJobs(state, limit)
end

---@param id integer
---@param time integer?
---@return sea.ComputeJob?
---@return string?
function ComputeJobs:requeue(id, time)
	local job = self.compute_jobs_repo:getComputeJob(id)
	if not job then
		return nil, "compute job not found"
	elseif job.state ~= "failed" and job.state ~= "dead" then
		return nil, "compute job is not failed or dead"
	end
	return assert(self.compute_jobs_repo:requeueComputeJob(id, time or os.time()))
end

---@param id integer?
---@param time integer?
---@return sea.ComputeResult?
---@return sea.ComputeFailure?
function ComputeJobs:process(id, time)
	time = time or os.time()
	if id then
		local existing_job = self.compute_jobs_repo:getComputeJob(id)
		if not existing_job then
			return nil, ComputeFailure.permanent("job_missing", "compute job not found")
		elseif existing_job.state == "succeeded" then
			return nil, ComputeFailure.permanent("already_succeeded", "compute job already succeeded")
		elseif existing_job.state == "failed" or existing_job.state == "dead" then
			return nil, ComputeFailure.permanent("job_terminal", "compute job is terminal")
		end
	end

	self.claim_index = self.claim_index + 1
	local lease_owner = ("%s:%d"):format(self.worker_id, self.claim_index)
	local job = self.compute_jobs_repo:claimComputeJob(time, lease_owner, self.lease_duration, id)
	if not job then
		return nil, ComputeFailure.transient("job_not_claimable", "no compute job is eligible for claim")
	end
	local chartplay = self.charts_repo:getChartplay(job.chartplay_id)
	if not chartplay then
		local failure = ComputeFailure.permanent("chartplay_missing", "chartplay not found")
		assert(self.compute_jobs_repo:failComputeJob(job, lease_owner, time, failure), "compute job lease lost")
		return nil, failure
	end

	local request, failure = self:createRequest(job, chartplay)
	if not request then
		---@cast failure sea.ComputeFailure
		self:recordFailure(job, chartplay, failure, lease_owner, os.time())
		return nil, failure
	end
	local result
	result, failure = self.replay_computer:compute(request)
	if not result then
		failure = failure or ComputeFailure.transient("compute_failed", "compute failed without a classified error")
		self:recordFailure(job, chartplay, failure, lease_owner, os.time())
		return nil, failure
	end
	if result.version ~= job.compute_version then
		failure = ComputeFailure.transient("version_mismatch", "compute result version mismatch")
		self:recordFailure(job, chartplay, failure, lease_owner, os.time())
		return nil, failure
	end
	local finalized
	finalized, failure = self:finalize(job, chartplay, result, lease_owner, os.time())
	if not finalized then
		if failure.code ~= "lease_expired" then
			self:recordFailure(job, chartplay, failure, lease_owner, os.time())
		end
		return nil, failure
	end
	return result
end

return ComputeJobs
