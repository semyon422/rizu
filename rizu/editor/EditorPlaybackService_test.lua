local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")

local test = {}

---@param t testing.T
function test.load_and_update_audio_timer(t)
	local calls = {}
	local editorModel = {
		configModel = {
			configs = {
				settings = {
					audio = {
						mode = "mono",
						volume = {
							master = 0.5,
							music = 0.8,
							keysounds = 0.25,
						},
					},
				},
			},
		},
		timer = {
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
		},
		audio_engine = {
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
		},
		chart = {
			id = "chart",
		},
	}

	local service = EditorPlaybackService()
	service:loadTimer(editorModel, {time = 2})
	service:loadAudio(editorModel)
	service:setTime(editorModel, 3)
	service:loadAudioResources(editorModel, {audio = "song.ogg"})
	service:updateAudio(editorModel)

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
	local editorModel = {
		intervalManager = {
			isGrabbed = function()
				return true
			end,
		},
		timer = {
			play = function()
				table.insert(calls, "timer")
			end,
		},
		audio_engine = {
			play = function()
				table.insert(calls, "audio")
			end,
		},
	}

	EditorPlaybackService():play(editorModel)

	t:tdeq(calls, {})
end

return test
