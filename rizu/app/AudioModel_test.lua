local AudioModel = require("rizu.app.AudioModel")
local bass = require("bass")

local test = {}

---@param t testing.T
function test.resolves_latency_presets(t)
	t:tdeq(AudioModel.getDeviceConfig("system", 7, 31), {period = 7, buffer = 31})
	t:tdeq(AudioModel.getDeviceConfig("safe", 0, 0), {period = 10, buffer = 40})
	t:tdeq(AudioModel.getDeviceConfig("balanced", 0, 0), {period = 5, buffer = 20})
	t:tdeq(AudioModel.getDeviceConfig("low_latency", 0, 0), {period = 5, buffer = 10})
	t:tdeq(AudioModel.getDeviceConfig("experimental", 0, 0), {period = 2, buffer = 5})
	t:tdeq(AudioModel.getDeviceConfig("custom", 3, 7), {period = 3, buffer = 7})

	local devices = {
		{id = 0, enabled = true, name = "No sound"},
		{id = 1, enabled = true, name = "Default", driver = "default"},
		{id = 2, enabled = true, name = "Analog", driver = "hw:1,0"},
		{id = 3, enabled = false, name = "Disabled", driver = "hw:2,0"},
		{id = 4, enabled = true, name = "PipeWire", driver = "pipewire"},
	}
	t:eq(AudioModel.resolveDeviceId("bass_default", devices), nil)
	t:eq(AudioModel.resolveDeviceId("sdl3_pipewire", devices), nil)
	local pipewire_id, pipewire_warning = AudioModel.resolveDeviceId("pipewire_low_latency", devices)
	t:eq(pipewire_id, 4)
	t:eq(pipewire_warning, nil)

	t:has_error(function()
		AudioModel.getDeviceConfig("unknown", 0, 0) --[[@as rizu.AudioDevicePreset]]
	end)
end

---@param t testing.T
function test.falls_back_to_no_sound_when_output_cannot_start(t)
	local real_start = bass.BASS_Start
	-- Simulates a device that passes BASS_Init but whose output cannot start
	-- (BASS_ERROR_START on every BASS_ChannelPlay).
	bass.BASS_Start = function() return 0 end

	local model = AudioModel()
	local ok, err = pcall(model.load, model, {period = 10, buffer = 40}, nil, "bass_default")

	bass.BASS_Start = real_start
	local device = tonumber(bass.BASS_GetDevice())
	if device >= 0 then
		bass.BASS_Free()
	end

	t:assert(ok, err)
	t:eq(device, 0)
	t:assert(model.startup_warning ~= nil)
end

return test
