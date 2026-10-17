local class = require("class")

---@class sea.ChartplayEffect
---@operator call: sea.ChartplayEffect
---@field id integer
---@field chartplay_id integer
---@field effect sea.ChartplayEffectType
---@field state sea.ComputeJobState
---@field attempt_count integer
---@field max_attempts integer
---@field created_at integer
---@field updated_at integer
---@field next_attempt_at integer
---@field lease_owner string?
---@field lease_expires_at integer?
---@field chart_upload_size integer
---@field replay_upload_size integer
---@field last_error_kind sea.ComputeFailureKind?
---@field last_error_code string?
---@field last_error_message string?
local ChartplayEffect = class()

return ChartplayEffect
