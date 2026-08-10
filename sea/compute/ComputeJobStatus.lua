local valid = require("valid")
local table_util = require("table_util")
local types = require("sea.shared.types")
local ComputeJobState = require("sea.compute.ComputeJobState")
local Chartplay = require("sea.chart.Chartplay")

---@class sea.ComputeJobStatus
---@field job_id integer
---@field chartplay_id integer
---@field state sea.ComputeJobState
---@field attempt_count integer
---@field max_attempts integer
---@field created_at integer
---@field updated_at integer
---@field next_attempt_at integer
---@field last_error_kind sea.ComputeFailureKind?
---@field last_error_code string?
---@field last_error_message string?
---@field chartplay sea.Chartplay?
local ComputeJobStatus = {}

local validate_status = valid.struct({
	job_id = valid.index,
	chartplay_id = valid.index,
	state = types.new_enum(ComputeJobState),
	attempt_count = types.count,
	max_attempts = types.count,
	created_at = types.time,
	updated_at = types.time,
	next_attempt_at = types.time,
	last_error_kind = valid.optional(valid.one_of({"permanent", "transient"})),
	last_error_code = valid.optional(types.name),
	last_error_message = valid.optional(types.string),
	chartplay = valid.optional(function(chartplay)
		if type(chartplay) ~= "table" then
			return nil, "not a table"
		end
		local values = table_util.sub(chartplay, table_util.keys(Chartplay.struct))
		return Chartplay.validate(values)
	end),
})

---@param job sea.ComputeJob
---@param chartplay sea.Chartplay?
---@return sea.ComputeJobStatus
function ComputeJobStatus.create(job, chartplay)
	return {
		job_id = assert(job.id),
		chartplay_id = job.chartplay_id,
		state = job.state,
		attempt_count = job.attempt_count,
		max_attempts = job.max_attempts,
		created_at = job.created_at,
		updated_at = job.updated_at,
		next_attempt_at = job.next_attempt_at,
		last_error_kind = job.last_error_kind,
		last_error_code = job.last_error_code,
		last_error_message = job.last_error_message,
		chartplay = chartplay,
	}
end

---@param status sea.ComputeJobStatus
---@return true?
---@return string|valid.Errors?
function ComputeJobStatus.validate(status)
	return validate_status(status)
end

return ComputeJobStatus
