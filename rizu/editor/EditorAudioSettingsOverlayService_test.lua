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
		volume = {},
	}
	local editor = {
		waveform = {},
	}
	local state = EditorAudioSettingsOverlayService():getState(createContext({
		audio = audio,
		editor = editor,
	}))

	t:eq(state.audio, audio)
	t:eq(state.editor, editor)
	t:eq(state.waveform, editor.waveform)
end

---@param t testing.T
function test.setters_mutate_settings(t)
	local audio = {
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
	service:setAudioOffset(context, 0.1)
	service:setWaveformOffset(context, 0.2)
	service:setWaveformOpacity(context, 0.3)
	service:setWaveformScale(context, 0.4)

	t:eq(audio.volume.master, 0.5)
	t:eq(editor.audioOffset, 0.1)
	t:eq(editor.waveformOffset, 0.2)
	t:eq(editor.waveform.opacity, 0.3)
	t:eq(editor.waveform.scale, 0.4)
end

return test
