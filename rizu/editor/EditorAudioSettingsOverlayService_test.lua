local EditorAudioSettingsOverlayService = require("rizu.editor.EditorAudioSettingsOverlayService")

local test = {}

local function createContext(fields)
	return {
		getAudioSettings = function()
			return fields.audio
		end,
		getEditorSettings = function()
			return fields.editor
		end,
	}
end

---@param t testing.T
function test.get_state_returns_audio_editor_and_waveform_settings(t)
	local audio = {
		volumeType = "linear",
		mode = {
			primary = "bass_sample",
			secondary = "love",
		},
		volume = {
			master = 0.9,
			music = 0.8,
			keysounds = 0.7,
			metronome = 0.6,
		},
	}
	local editor = {
		audioOffset = 0.1,
		waveformOffset = -0.05,
		waveform = {
			opacity = 0.4,
			scale = 0.5,
		},
	}
	local state = EditorAudioSettingsOverlayService():getState(createContext({
		audio = audio,
		editor = editor,
	}))

	t:eq(state.audio, audio)
	t:eq(state.editor, editor)
	t:eq(state.waveform, editor.waveform)
	t:tdeq(state.volumeSliders, {
		{
			key = "master",
			label = "master 0.90",
			value = 0.9,
			min = 0,
			max = 1,
			step = 0.01,
		},
		{
			key = "music",
			label = "music 0.80",
			value = 0.8,
			min = 0,
			max = 1,
			step = 0.01,
		},
		{
			key = "keysounds",
			label = "keysounds 0.70",
			value = 0.7,
			min = 0,
			max = 1,
			step = 0.01,
		},
		{
			key = "metronome",
			label = "metronome 0.60",
			value = 0.6,
			min = 0,
			max = 1,
			step = 0.01,
		},
	})
	t:tdeq(state.audioOffsetSlider, {
		key = "ed.audioOffset",
		label = "main audio offset 100ms",
		value = 100,
		min = -200,
		max = 200,
		step = 1,
	})
	t:tdeq(state.waveformOffsetSlider, {
		key = "ed.waveformOffset",
		label = "waveform offset -50ms",
		value = -50,
		min = -200,
		max = 200,
		step = 1,
	})
	t:tdeq(state.waveformOpacitySlider, {
		key = "wf.opacity",
		label = "opacity 0.40",
		value = 0.4,
		min = 0,
		max = 1,
		step = 0.01,
	})
	t:tdeq(state.waveformScaleSlider, {
		key = "wf.scale",
		label = "scale 0.50",
		value = 0.5,
		min = 0,
		max = 1,
		step = 0.01,
	})
	t:eq(state.primaryModeLabel, "primary: bass_sample")
	t:eq(state.secondaryModeLabel, "secondary: love")
end

---@param t testing.T
function test.get_state_returns_logarithmic_volume_sliders(t)
	local state = EditorAudioSettingsOverlayService():getState(createContext({
		audio = {
			volumeType = "logarithmic",
			mode = {
				primary = "bass_sample",
				secondary = "love",
			},
			volume = {
				master = 0.5,
				music = -0.25,
				keysounds = 0.125,
				metronome = 2,
			},
		},
		editor = {
			audioOffset = 0,
			waveformOffset = 0,
			waveform = {
				opacity = 1,
				scale = 1,
			},
		},
	}))

	t:tdeq(state.volumeSliders[1], {
		key = "master",
		label = "master -6dB",
		value = -6,
		min = -60,
		max = 0,
		step = 1,
	})
	t:eq(state.volumeSliders[2].value, -60)
	t:eq(state.volumeSliders[4].value, 0)
end

---@param t testing.T
function test.setters_mutate_settings(t)
	local audio = {
		mode = {
			primary = "bass_sample",
			secondary = "love",
		},
		volume = {},
	}
	local editor = {
		waveform = {},
	}
	local context = createContext({
		audio = audio,
		editor = editor,
	})
	local service = EditorAudioSettingsOverlayService()

	service:setVolume(context, "master", 0.5)
	service:setVolume(context, "music", -0.5)
	service:setVolume(context, "keysounds", 2)
	service:setAudioOffset(context, 0.1)
	service:setWaveformOffset(context, 0.2)
	service:setWaveformOpacity(context, 0.3)
	service:setWaveformScale(context, 0.4)

	t:eq(audio.volume.master, 0.5)
	t:eq(audio.volume.music, 0)
	t:eq(audio.volume.keysounds, 1)
	t:eq(editor.audioOffset, 0.1)
	t:eq(editor.waveformOffset, 0.2)
	t:eq(editor.waveform.opacity, 0.3)
	t:eq(editor.waveform.scale, 0.4)
end

---@param t testing.T
function test.handle_input_mutates_settings(t)
	local audio = {
		volumeType = "linear",
		mode = {
			primary = "bass_sample",
			secondary = "love",
		},
		volume = {
			master = 1,
			music = 1,
			keysounds = 1,
			metronome = 1,
		},
	}
	local editor = {
		audioOffset = 0,
		waveformOffset = 0,
		waveform = {
			opacity = 1,
			scale = 1,
		},
	}
	local context = createContext({
		audio = audio,
		editor = editor,
	})

	EditorAudioSettingsOverlayService():handleInput(context, {
		volumes = {
			master = 0.7,
			music = 0.6,
			keysounds = 0.5,
			metronome = 0.4,
		},
		audioOffsetMilliseconds = 123,
		waveformOffsetMilliseconds = -45,
		waveformOpacity = 0.3,
		waveformScale = 0.2,
	})

	t:eq(audio.volume.master, 0.7)
	t:eq(audio.volume.music, 0.6)
	t:eq(audio.volume.keysounds, 0.5)
	t:eq(audio.volume.metronome, 0.4)
	t:eq(editor.audioOffset, 0.123)
	t:eq(editor.waveformOffset, -0.045)
	t:eq(editor.waveform.opacity, 0.3)
	t:eq(editor.waveform.scale, 0.2)
end

---@param t testing.T
function test.handle_input_converts_logarithmic_volume_to_linear_storage(t)
	local audio = {
		volumeType = "logarithmic",
		mode = {
			primary = "bass_sample",
			secondary = "love",
		},
		volume = {
			master = 1,
		},
	}
	local editor = {
		audioOffset = 0,
		waveformOffset = 0,
		waveform = {
			opacity = 1,
			scale = 1,
		},
	}
	local context = createContext({
		audio = audio,
		editor = editor,
	})

	EditorAudioSettingsOverlayService():handleInput(context, {
		volumes = {
			master = -6,
		},
		audioOffsetMilliseconds = 0,
		waveformOffsetMilliseconds = 0,
		waveformOpacity = 1,
		waveformScale = 1,
	})

	t:eq(math.abs(audio.volume.master - 10 ^ (-6 / 20)) < 0.000001, true)
end

return test
