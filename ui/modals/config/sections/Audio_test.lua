local Audio = require("ui.modals.config.sections.Audio")
local FakeFilesystem = require("fs.FakeFilesystem")
local View = require("gui.View")
local Localization = require("ui.localization.Localization")
local Label = require("ui.views.Label")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local FormControl = require("ui.views.form.FormControl")
local SegmentedControl = require("ui.views.form.SegmentedControl")

local test = {}

---@param preset? rizu.AudioDevicePreset
---@param audio_model? rizu.AudioModel
---@return rizu.config.Config, ui.views.form.Dropdown, gui.View[]
local function createAudioControls(preset, audio_model)
	local old_sprites = Resources.sprites
	local old_get_font = Resources.getFont
	local sprite = {
		getWidth = function() return 10 end,
		getHeight = function() return 20 end,
	}
	Resources.sprites = {
		segmented_bg_left = sprite,
		segmented_bg_middle = sprite,
		segmented_bg_right = sprite,
		slider_line_left = sprite,
		slider_line_middle = sprite,
		slider_line_right = sprite,
		slider_thumb = sprite,
		form_element_cap_left = sprite,
		form_element_cap_middle = sprite,
		form_element_cap_right = sprite,
		icon_chevron = sprite,
		icon_volume_1 = sprite,
	}
	Resources.getFont = function()
		return {
			getHeight = function() return 16 end,
			getWidth = function(_, text) return #text * 8 end,
			getWrap = function(_, text) return #text * 8, {text} end,
		}
	end

	local fs = FakeFilesystem()
	fs:createDirectory("userdata")
	local settings = Settings.createConfig(fs)
	if preset then
		settings:setChoice(Settings.keys.audio.device_preset, preset)
	end
	local controls = Audio(settings, Localization(), audio_model, nil, View()):build()
	Resources.sprites = old_sprites
	Resources.getFont = old_get_font

	local key = Settings.keys.audio.device_preset
	for _, control in ipairs(controls) do
		if FormControl * control and control.setting_key == key then
			return settings, control --[[@as ui.views.form.Dropdown]], controls
		end
	end
	error("audio latency control was not created")
end

---@param t testing.T
function test.latency_preset_binds_audio_setting(t)
	local settings, control = createAudioControls()
	local key = Settings.keys.audio.device_preset

	t:eq(control.setting_name, "Audio latency")
	t:eq(settings:getChoice(key), "system")
	t:tdeq(control.options, {
		"system", "safe", "balanced", "low_latency", "experimental", "custom",
	})
	control:setValue("experimental", true)
	t:eq(settings:getChoice(key), "experimental")
end

---@param t testing.T
function test.music_playback_mode_binds_audio_setting(t)
	local settings, _, controls = createAudioControls()
	---@type ui.views.form.SegmentedControl?
	local music_mode_control
	for _, control in ipairs(controls) do
		if SegmentedControl * control then
			local segmented = control --[[@as ui.views.form.SegmentedControl]]
			if segmented.setting_key == Settings.keys.audio.mode_primary then
				music_mode_control = segmented
			end
			t:ne(segmented.setting_key, Settings.keys.audio.mode_secondary)
		end
	end

	local keys = Settings.keys.audio
	assert(music_mode_control)
	t:tdeq(music_mode_control.options, {"bass_sample", "bass_fx_tempo"})
	music_mode_control:setValue("bass_sample", true)
	t:eq(settings:getChoice(keys.mode_primary), "bass_sample")
	t:eq(settings:getChoice(keys.mode_secondary), "bass_sample")
end

---@param t testing.T
function test.custom_latency_exposes_period_and_buffer(t)
	local _, _, controls = createAudioControls("custom")
	---@type {[string]: boolean}
	local found = {}
	for _, item in ipairs(controls) do
		if FormControl * item then
			local form_control = item --[[@as ui.views.form.FormControl]]
			local key = form_control.setting_key
			if key then
				found[key] = true
			end
		end
	end
	local keys = Settings.keys.audio
	t:assert(found[keys.device_period])
	t:assert(found[keys.device_buffer])
end

---@param t testing.T
function test.shows_runtime_audio_status_and_backends(t)
	local audio_model = {
		getStatus = function()
			return {
				latency = 8,
				min_buffer = 5,
				period = 5,
				buffer = 10,
				device_id = 16,
				device_name = "PipeWire Sound Server",
				device_driver = "pipewire",
			}
		end,
	} --[[@as rizu.AudioModel]]
	local _, _, controls = createAudioControls(nil, audio_model)
	---@type string[]
	local texts = {}
	---@type ui.views.form.SegmentedControl?
	local backend_control
	for _, control in ipairs(controls) do
		if Label * control then
			local label = control --[[@as ui.views.Label]]
			texts[#texts + 1] = label.text
		elseif SegmentedControl * control then
			local segmented = control --[[@as ui.views.form.SegmentedControl]]
			if segmented.setting_key == Settings.keys.audio.backend then
				backend_control = segmented
			end
		end
	end
	assert(backend_control)
	t:tdeq(backend_control.options, {"bass_default", "pipewire_low_latency", "sdl3_pipewire"})
	t:tdeq(texts, {
		"Active device: PipeWire Sound Server (pipewire)",
		"Actual: 8 ms · minimum: 5 ms · period: 5 ms · buffer: 10 ms",
	})
end

---@param t testing.T
function test.shows_sdl_queue_diagnostics(t)
	local audio_model = {
		getStatus = function()
			return {
				latency = 15.8,
				min_buffer = 5.8,
				period = 5.8,
				buffer = 10,
				device_id = 15,
				device_name = "Built-in Audio Analog Stereo",
				device_driver = "pipewire",
				transport = "SDL3",
				queued_ms = 9.9,
				underruns = 2,
			}
		end,
	} --[[@as rizu.AudioModel]]
	local _, _, controls = createAudioControls(nil, audio_model)
	---@type string[]
	local texts = {}
	for _, control in ipairs(controls) do
		if Label * control then
			local label = control --[[@as ui.views.Label]]
			texts[#texts + 1] = label.text
		end
	end
	t:tdeq(texts, {
		"Active device: Built-in Audio Analog Stereo (pipewire)",
		"Target: 15.8 ms · period: 5.8 ms · queue: 10 ms",
		"SDL queue now: 9.9 ms · observed underruns: 2",
	})
end

return test
