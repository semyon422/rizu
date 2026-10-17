local EditorFooterService = require("rizu.editor.view.EditorFooterService")

local test = {}

local function createContext(fields)
	return {
		getPoint = function()
			return fields.point
		end,
		isPlaying = function()
			return fields.playing == true
		end,
		play = function()
			fields.playing = true
			table.insert(fields.calls, "play")
		end,
		pause = function()
			fields.playing = false
			table.insert(fields.calls, "pause")
		end,
		getRate = function()
			return fields.rate
		end,
		setRate = function(_, rate)
			fields.rate = rate
			table.insert(fields.calls, "rate:" .. rate)
		end,
	}
end

---@param t testing.T
function test.get_state_reads_time_playback_and_rate(t)
	local context = createContext({
		calls = {},
		point = {
			absoluteTime = 12.5,
		},
		playing = true,
		rate = 0.75,
	})

	local state = EditorFooterService():getState(context)

	t:eq(state.absoluteTime, 12.5)
	t:eq(state.absoluteTimeLabel, "00:12.500")
	t:eq(state.playPauseLabel, "pause")
	t:eq(state.rate, 0.75)
	t:eq(state.rateLabel, "0.75x")
	t:eq(state.rateMin, 0.5)
	t:eq(state.rateMax, 2)
	t:eq(state.rateStep, 0.01)
end

---@param t testing.T
function test.toggle_playback_switches_between_play_and_pause(t)
	local calls = {}
	local context = createContext({
		calls = calls,
		point = {},
		playing = false,
		rate = 1,
	})
	local service = EditorFooterService()

	service:togglePlayback(context)
	service:togglePlayback(context)

	t:tdeq(calls, {"play", "pause"})
end

---@param t testing.T
function test.set_rate_clamps_to_supported_range(t)
	local calls = {}
	local context = createContext({
		calls = calls,
		point = {},
		rate = 1,
	})
	local service = EditorFooterService()

	service:setRate(context, 0.1)
	service:setRate(context, 1.5)
	service:setRate(context, 3)

	t:eq(context:getRate(), 2)
	t:tdeq(calls, {"rate:0.5", "rate:1.5", "rate:2"})
end

---@param t testing.T
function test.handle_input_toggles_playback_and_maps_rate_fraction(t)
	local calls = {}
	local context = createContext({
		calls = calls,
		point = {
			absoluteTime = 0,
		},
		playing = false,
		rate = 0.5,
	})
	local service = EditorFooterService()
	local state = service:getState(context)

	service:handleInput(context, state, {
		togglePlayback = true,
		rateFraction = 0.25,
	})

	t:tdeq(calls, {"play", "rate:0.88"})
end

return test
