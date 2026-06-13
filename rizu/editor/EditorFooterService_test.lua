local EditorFooterService = require("rizu.editor.EditorFooterService")

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
	t:eq(state.playPauseLabel, "pause")
	t:eq(state.rate, 0.75)
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

	t:eq(context:getRate(), 1)
	t:tdeq(calls, {"rate:0.25", "rate:1"})
end

return test
