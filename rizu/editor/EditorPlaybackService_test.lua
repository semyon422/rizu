local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")

local test = {}

---@param t testing.T
function test.load_and_update_audio_timer(t)
	local calls = {}
	local audioSettings = {
		mode = "mono",
		volume = {
			master = 0.5,
			music = 0.8,
			keysounds = 0.25,
		},
	}
	local timer = {
		pause = function()
			table.insert(calls, "timer-pause")
		end,
		setTime = function(_, time, exact)
			table.insert(calls, ("timer-time:%s:%s"):format(time, tostring(exact)))
		end,
		getTime = function()
			table.insert(calls, "timer-get")
			return 1.5
		end,
	}
	local audioEngine = {
		setVolume = function(_, music, keysounds)
			table.insert(calls, ("volume:%s:%s"):format(music, keysounds))
		end,
		setAudioMode = function(_, mode)
			table.insert(calls, "mode:" .. mode)
		end,
		setPosition = function(_, time)
			table.insert(calls, "position:" .. time)
		end,
		setEnabled = function(_, enabled)
			table.insert(calls, "enabled:" .. tostring(enabled))
		end,
		load = function(_, chart, resources)
			table.insert(calls, "load:" .. chart.id .. ":" .. resources.audio)
		end,
		update = function()
			table.insert(calls, "update")
		end,
	}
	local chart = {
		id = "chart",
	}

	local service = EditorPlaybackService()
	service:loadTimer(timer, {time = 2})
	service:loadAudio(audioEngine, audioSettings)
	service:setTime(timer, audioEngine, 3)
	service:loadAudioResources(audioEngine, timer, chart, {audio = "song.ogg"})
	service:updateAudio(audioEngine)

	t:tdeq(calls, {
		"timer-pause",
		"timer-time:2:nil",
		"volume:0.4:0.125",
		"mode:mono",
		"timer-time:3:true",
		"position:3",
		"enabled:true",
		"load:chart:song.ogg",
		"timer-get",
		"position:1.5",
		"update",
	})
end

---@param t testing.T
function test.play_respects_grabbed_interval(t)
	local calls = {}
	local timer = {
		play = function()
			table.insert(calls, "timer")
		end,
	}
	local audioEngine = {
		play = function()
			table.insert(calls, "audio")
		end,
	}

	EditorPlaybackService():play(timer, audioEngine, function()
		return true
	end)

	t:tdeq(calls, {})
end

---@param t testing.T
function test.editor_context_commands(t)
	local calls = {}
	local context = {
		getTimer = function()
			return {
				setTime = function(_, time, exact)
					table.insert(calls, ("timer-time:%s:%s"):format(time, tostring(exact)))
				end,
				getTime = function()
					table.insert(calls, "timer-get")
					return 2.5
				end,
				play = function()
					table.insert(calls, "timer-play")
				end,
				pause = function()
					table.insert(calls, "timer-pause")
				end,
			}
		end,
		getAudioEngine = function()
			return {
				setPosition = function(_, time)
					table.insert(calls, "position:" .. time)
				end,
				setEnabled = function(_, enabled)
					table.insert(calls, "enabled:" .. tostring(enabled))
				end,
				load = function(_, chart, resources)
					table.insert(calls, "load:" .. chart.id .. ":" .. resources.audio)
				end,
				play = function()
					table.insert(calls, "audio-play")
				end,
				pause = function()
					table.insert(calls, "audio-pause")
				end,
			}
		end,
		getChart = function()
			return {
				id = "chart",
			}
		end,
		getIntervalManager = function()
			return {
				isGrabbed = function()
					table.insert(calls, "grabbed")
					return false
				end,
			}
		end,
	}
	local service = EditorPlaybackService()

	service:setEditorTime(context, 1.25)
	service:loadEditorAudioResources(context, {audio = "song.ogg"})
	service:playEditor(context)
	service:pauseEditor(context)

	t:tdeq(calls, {
		"timer-time:1.25:true",
		"position:1.25",
		"enabled:true",
		"load:chart:song.ogg",
		"timer-get",
		"position:2.5",
		"grabbed",
		"timer-play",
		"audio-play",
		"timer-pause",
		"audio-pause",
	})
end

return test
