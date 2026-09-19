local AudioModel = require("rizu.app.AudioModel")

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
	local pipewire_id, pipewire_warning = AudioModel.resolveDeviceId("pipewire_low_latency", devices)
	t:eq(pipewire_id, 4)
	t:eq(pipewire_warning, nil)

	t:has_error(function()
		AudioModel.getDeviceConfig("unknown", 0, 0) --[[@as rizu.AudioDevicePreset]]
	end)
end

return test
