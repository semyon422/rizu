local valid = require("valid")
local ComputeJobStatus = require("sea.compute.ComputeJobStatus")

---@class sea.ChartplaySubmissionResult
---@field status sea.ComputeJobStatus
---@field duplicate boolean
local ChartplaySubmissionResult = {}

local validate_result = valid.struct({
	status = ComputeJobStatus.validate,
	duplicate = function(value)
		return type(value) == "boolean"
	end,
})

---@param result sea.ChartplaySubmissionResult
---@return true?
---@return string|valid.Errors?
function ChartplaySubmissionResult.validate(result)
	return validate_result(result)
end

return ChartplaySubmissionResult
