local EditorAudioOverlayService = require("rizu.editor.EditorAudioOverlayService")

local test = {}

local function createContext(fields)
	return {
		getAudioEngine = function()
			return fields.audioEngine
		end,
		getTimerTime = function()
			return fields.timerTime
		end,
	}
end

---@param t testing.T
function test.get_state_counts_playing_sources_and_offsync(t)
	local state = EditorAudioOverlayService():getState(createContext({
		timerTime = 12.5,
		audioEngine = {
			source = {
				is_playing = true,
			},
			foregroundSource = {
				is_playing = false,
			},
			getPosition = function()
				return 12.25
			end,
		},
	}))

	t:eq(state.playingCount, 1)
	t:eq(state.offsync, 0.25)
	t:eq(state.playingCountLabel, "playing sounds: 1")
	t:eq(state.offsyncLabel, "offsync: 250ms")
end

---@param t testing.T
function test.get_state_uses_zero_offsync_without_audio_position(t)
	local state = EditorAudioOverlayService():getState(createContext({
		timerTime = 12.5,
		audioEngine = {
			foregroundSource = {
				is_playing = true,
			},
			getPosition = function()
				return nil
			end,
		},
	}))

	t:eq(state.playingCount, 1)
	t:eq(state.offsync, 0)
	t:eq(state.playingCountLabel, "playing sounds: 1")
	t:eq(state.offsyncLabel, "offsync: 0ms")
end

return test
