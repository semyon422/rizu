local class = require("class")
local sql_util = require("rdb.sql_util")

---@class sea.ComputeJobsRepo
---@operator call: sea.ComputeJobsRepo
local ComputeJobsRepo = class()

---@param models rdb.Models
function ComputeJobsRepo:new(models)
	self.models = models
end

---@param id integer
---@return sea.ComputeJob?
function ComputeJobsRepo:getComputeJob(id)
	return self.models.compute_jobs:find({id = assert(id)})
end

---@param chartplay_id integer
---@return sea.ComputeJob?
function ComputeJobsRepo:getComputeJobByChartplayId(chartplay_id)
	return self.models.compute_jobs:find({chartplay_id = assert(chartplay_id)})
end

---@param idempotency_key string
---@return sea.ComputeJob?
function ComputeJobsRepo:getComputeJobByIdempotencyKey(idempotency_key)
	return self.models.compute_jobs:find({idempotency_key = assert(idempotency_key)})
end

---@param compute_job sea.ComputeJob
---@return sea.ComputeJob
function ComputeJobsRepo:createComputeJob(compute_job)
	return self.models.compute_jobs:create(compute_job)
end

---@param now integer
---@param lease_owner string
---@param lease_duration integer
---@param id integer?
---@return sea.ComputeJob?
function ComputeJobsRepo:claimComputeJob(now, lease_owner, lease_duration, id)
	local id_condition = id and "AND id = ?" or ""
	local values = {now, lease_owner, now + lease_duration, now, now}
	if id then
		table.insert(values, id)
	end
	local rows = self.models.compute_jobs.orm:query(([=[
		UPDATE compute_jobs
		SET state = 1,
			attempt_count = attempt_count + 1,
			updated_at = ?,
			lease_owner = ?,
			lease_expires_at = ?,
			last_error_kind = NULL,
			last_error_code = NULL,
			last_error_message = NULL
		WHERE id = (
			SELECT id FROM compute_jobs
			WHERE attempt_count < max_attempts
			AND (state = 0 AND next_attempt_at <= ?
				OR state = 1 AND lease_expires_at <= ?)
			%s
			ORDER BY created_at, id
			LIMIT 1
		)
	]=]):format(id_condition), values)
	if not rows[1] then
		return nil
	end
	return self.models.compute_jobs:row_from_db(rows[1])
end

---@param job sea.ComputeJob
---@param lease_owner string
---@param time integer
---@param timings sea.ComputeStageTimings
---@return sea.ComputeJob?
function ComputeJobsRepo:succeedComputeJob(job, lease_owner, time, timings)
	return self.models.compute_jobs:update({
		state = "succeeded",
		updated_at = time,
		lease_owner = sql_util.NULL,
		lease_expires_at = sql_util.NULL,
		replay_load_time = timings.replay_load,
		chart_parse_time = timings.chart_parse,
		difficulty_time = timings.difficulty,
		replay_time = timings.replay,
	}, {
		id = assert(job.id),
		state = "running",
		lease_owner = assert(lease_owner),
	})[1]
end

---@param job sea.ComputeJob
---@param lease_owner string
---@param time integer
---@param failure sea.ComputeFailure
---@return sea.ComputeJob?
function ComputeJobsRepo:failComputeJob(job, lease_owner, time, failure)
	return self.models.compute_jobs:update({
		state = "failed",
		updated_at = time,
		lease_owner = sql_util.NULL,
		lease_expires_at = sql_util.NULL,
		last_error_kind = failure.kind,
		last_error_code = failure.code,
		last_error_message = failure.message:sub(1, 4096),
	}, {
		id = assert(job.id),
		state = "running",
		lease_owner = assert(lease_owner),
	})[1]
end

---@param job sea.ComputeJob
---@param lease_owner string
---@param time integer
---@param failure sea.ComputeFailure
---@param retry_delay integer
---@return sea.ComputeJob?
function ComputeJobsRepo:retryComputeJob(job, lease_owner, time, failure, retry_delay)
	local state = job.attempt_count >= job.max_attempts and "dead" or "queued"
	return self.models.compute_jobs:update({
		state = state,
		updated_at = time,
		next_attempt_at = time + retry_delay,
		lease_owner = sql_util.NULL,
		lease_expires_at = sql_util.NULL,
		last_error_kind = failure.kind,
		last_error_code = failure.code,
		last_error_message = failure.message:sub(1, 4096),
	}, {
		id = assert(job.id),
		state = "running",
		lease_owner = assert(lease_owner),
	})[1]
end

return ComputeJobsRepo
