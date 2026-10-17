local Enum = require("rdb.Enum")

---@enum (key) sea.ComputeJobState
local ComputeJobState = {
	queued = 0,
	running = 1,
	succeeded = 2,
	failed = 3,
	dead = 4,
}

return Enum(ComputeJobState)
