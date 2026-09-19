---@alias rizu.AudioBackend "bass_default"|"pipewire_low_latency"|"sdl3_pipewire"

---@class rizu.audio.OutputConfigData
---@field backend rizu.AudioBackend
---@field period number
---@field buffer number

---@class rizu.audio.OutputRuntimeStatus
---@field queued_ms number
---@field target_queue_ms number
---@field period_ms number
---@field underruns integer

local OutputConfig = {}

---@type rizu.audio.OutputConfigData
local current = {
	backend = "bass_default",
	period = 0,
	buffer = 0,
}

---@type rizu.audio.OutputRuntimeStatus?
local runtime_status

---@param config rizu.audio.OutputConfigData
function OutputConfig.set(config)
	current = {
		backend = config.backend,
		period = config.period,
		buffer = config.buffer,
	}
	runtime_status = nil
end

---@return rizu.audio.OutputConfigData
function OutputConfig.get()
	return current
end

---@param status rizu.audio.OutputRuntimeStatus?
function OutputConfig.setRuntimeStatus(status)
	runtime_status = status
end

---@return rizu.audio.OutputRuntimeStatus?
function OutputConfig.getRuntimeStatus()
	return runtime_status
end

return OutputConfig
