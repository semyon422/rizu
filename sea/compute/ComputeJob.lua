local class = require("class")

---@class sea.ComputeJob
---@operator call: sea.ComputeJob
---@field id integer
---@field chartplay_id integer
---@field idempotency_key string
---@field state sea.ComputeJobState
---@field attempt_count integer
---@field max_attempts integer
---@field created_at integer
---@field updated_at integer
---@field next_attempt_at integer
---@field lease_owner string?
---@field lease_expires_at integer?
---@field compute_version string
---@field chartdiff sea.Chartdiff
---@field last_error_kind sea.ComputeFailureKind?
---@field last_error_code string?
---@field last_error_message string?
---@field replay_load_time number?
---@field chart_parse_time number?
---@field difficulty_time number?
---@field replay_time number?
local ComputeJob = class()

return ComputeJob
