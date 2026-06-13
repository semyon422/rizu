local EditorWaveformService = require("rizu.editor.EditorWaveformService")

local test = {}

local function createWave(samples)
	return {
		sample_rate = 10,
		samples_count = #samples,
		channels_count = 1,
		getSampleFloat = function(_, i)
			return samples[i + 1]
		end,
	}
end

local function createContext(fields)
	return {
		getWave = function()
			return fields.wave
		end,
		getSessionTime = function()
			return fields.sessionTime
		end,
		getAudioStartTime = function()
			return fields.audioStartTime
		end,
	}
end

---@param t testing.T
function test.update_returns_nil_without_wave(t)
	local state = EditorWaveformService():update(createContext({
		wave = nil,
	}), {}, {})

	t:eq(state, nil)
end

---@param t testing.T
function test.update_builds_waveform_lines_from_samples(t)
	local service = EditorWaveformService()
	local state = service:update(createContext({
		wave = createWave({0.5, -0.25, 0.75, -0.5}),
		sessionTime = 0,
		audioStartTime = 0,
	}), {
		fullWidth = 100,
		unit = 2,
	}, {
		speed = 5,
		waveformOffset = 0,
	})

	t:ne(state, nil)
	---@cast state -nil
	t:eq(state.channelCount, 1)
	t:eq(state.pointDrawDelta, 0)
	t:tdeq(state.lines[0], {25, 1, -12.5, 0, 25, 0, -12.5, -1, 37.5, -1})
end

---@param t testing.T
function test.update_tracks_fractional_point_draw_delta(t)
	local service = EditorWaveformService()
	local state = service:update(createContext({
		wave = createWave({0.5, 0.5, 0.5, 0.5}),
		sessionTime = 0.15,
		audioStartTime = 0,
	}), {
		fullWidth = 100,
		unit = 2,
	}, {
		speed = 2,
		waveformOffset = 0,
	})

	t:ne(state, nil)
	---@cast state -nil
	t:eq(state.pointDrawDelta, 0.4)
end

return test
