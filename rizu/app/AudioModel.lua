local class = require("class")
local ffi = require("ffi")
local bass = require("bass")
local bass_config = require("bass.config")

---@alias rizu.AudioDevicePreset "system"|"safe"|"balanced"|"low_latency"|"experimental"|"custom"
---@alias rizu.AudioBackend "bass_default"|"pipewire_low_latency"

---@class rizu.AudioDeviceConfig
---@field period number
---@field buffer number

---@class rizu.BassDeviceInfo: ffi.cdata*
---@field latency number
---@field minbuf number

---@class rizu.AudioDeviceStatus
---@field latency number
---@field min_buffer number
---@field period number
---@field buffer number
---@field device_id integer
---@field device_name string
---@field device_driver string
---@field warning string?

---@class rizu.AudioModel
---@operator call: rizu.AudioModel
local AudioModel = class()

---@type {[rizu.AudioDevicePreset]: rizu.AudioDeviceConfig}
AudioModel.device_presets = {
	safe = {period = 10, buffer = 40},
	balanced = {period = 5, buffer = 20},
	low_latency = {period = 5, buffer = 10},
	experimental = {period = 2, buffer = 5},
}

---@param preset rizu.AudioDevicePreset
---@param custom_period number
---@param custom_buffer number
---@return rizu.AudioDeviceConfig
function AudioModel.getDeviceConfig(preset, custom_period, custom_buffer)
	local config = AudioModel.device_presets[preset]
	if config then
		return {period = config.period, buffer = config.buffer}
	end
	assert(preset == "system" or preset == "custom", "Unknown audio device preset: " .. tostring(preset))
	return {period = custom_period, buffer = custom_buffer}
end

---@param backend rizu.AudioBackend
---@param devices bass.Device[]
---@return integer? device_id
---@return string? warning
function AudioModel.resolveDeviceId(backend, devices)
	if backend == "bass_default" then
		return nil
	end
	assert(backend == "pipewire_low_latency", "Unknown audio backend: " .. tostring(backend))
	if jit.os ~= "Linux" then
		return nil, "PipeWire low latency is only available on Linux; using the default output device."
	end
	for _, device in ipairs(devices) do
		if device.enabled and device.driver == "pipewire" then
			return device.id
		end
	end
	return nil, "The PipeWire ALSA plugin is unavailable; using the default output device."
end

---@param backend rizu.AudioBackend
---@return integer? device_id
---@return string? warning
function AudioModel:findDeviceId(backend)
	local device_id, warning = AudioModel.resolveDeviceId(backend, bass.getDevices())
	self.startup_warning = warning
	return device_id, warning
end

---@param device rizu.AudioDeviceConfig
local function configurePipeWireLatency(device)
	if jit.os ~= "Linux" then
		return
	end
	pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
	local target_frames = device.buffer / 1000 * 48000
	local quantum = 2 ^ math.floor(math.log(target_frames) / math.log(2) + 0.5)
	quantum = math.max(32, math.min(2048, quantum))
	ffi.C.setenv("PIPEWIRE_LATENCY", quantum .. "/48000", 1)
end

---@return rizu.AudioDeviceStatus
function AudioModel:getStatus()
	local info = bass.getInfo()
	---@cast info rizu.BassDeviceInfo
	local device_id = tonumber(bass.BASS_GetDevice())
	local device_name = "Unknown"
	local device_driver = ""
	for _, device in ipairs(bass.getDevices()) do
		if device.id == device_id then
			device_name = device.name or device_name
			device_driver = device.driver or device_driver
			break
		end
	end
	return {
		latency = tonumber(info.latency),
		min_buffer = tonumber(info.minbuf),
		period = assert(tonumber(bass.BASS_GetConfig(bass_config.BASS_CONFIG_DEV_PERIOD))),
		buffer = assert(tonumber(bass.BASS_GetConfig(bass_config.BASS_CONFIG_DEV_BUFFER))),
		device_id = device_id,
		device_name = device_name,
		device_driver = device_driver,
		warning = self.startup_warning,
	}
end

---@param device rizu.AudioDeviceConfig
---@param device_id integer?
---@param backend rizu.AudioBackend
function AudioModel:load(device, device_id, backend)
	if device.period == 0 then
		device.period = bass.default_dev_period
	end
	if device.buffer == 0 then
		device.buffer = bass.default_dev_buffer
	end
	bass.setDevicePeriod(device.period)
	bass.setDeviceBuffer(device.buffer)
	if backend == "pipewire_low_latency" then
		configurePipeWireLatency(device)
	end
	bass.init(device_id)
	if tonumber(bass.BASS_GetDevice()) >= 0 then
		return
	end
	assert(device_id, "Could not initialize the default BASS output device")
	self.startup_warning = "The selected audio device failed to initialize; using the default output device."
	print("AudioModel: " .. self.startup_warning)
	bass.init()
	assert(tonumber(bass.BASS_GetDevice()) >= 0, "Could not initialize the fallback BASS output device")
end

return AudioModel
