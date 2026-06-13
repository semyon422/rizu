local EditorModelFrameService = require("rizu.editor.EditorModelFrameService")

local test = {}

---@param t testing.T
function test.update_order(t)
	local calls = {}
	local editor = {}
	local noteSkin = {}
	local point = {}
	local context = {
		getSettings = function()
			table.insert(calls, "settings")
			return editor
		end,
		getNoteSkin = function()
			table.insert(calls, "skin")
			return noteSkin
		end,
		getTimer = function()
			return {
				getTime = function()
					table.insert(calls, "timer")
					return 0.5
				end,
			}
		end,
		getNoteService = function()
			return {
				update = function()
					table.insert(calls, "notes")
				end,
			}
		end,
		getMetronome = function()
			return {
				update = function()
					table.insert(calls, "metronome")
				end,
			}
		end,
		getSelectionService = function()
			return {
				updateSelectionRect = function(_, selectionContext, frameEditor, frameNoteSkin, time)
					table.insert(calls, "selection:" .. time)
					t:eq(frameEditor, editor)
					t:eq(frameNoteSkin, noteSkin)
				end,
			}
		end,
		getDtpAbsolute = function(_, time)
			table.insert(calls, "point:" .. time)
			return point
		end,
		getIntervalManager = function()
			return {
				grabbedVertex = true,
				moveGrabbed = function(_, time)
					table.insert(calls, "timing:" .. time)
				end,
			}
		end,
		getPlaybackService = function()
			return {
				updateAudio = function(_, audioEngine)
					table.insert(calls, "audio")
					t:eq(audioEngine.id, "audio")
				end,
			}
		end,
		getAudioEngine = function()
			return {
				id = "audio",
			}
		end,
		setSessionPoint = function(_, framePoint)
			table.insert(calls, "cursor")
			t:eq(framePoint, point)
		end,
		getVisualEngine = function()
			return {
				update = function()
					table.insert(calls, "visuals")
				end,
			}
		end,
	}

	EditorModelFrameService():update(context)

	t:tdeq(calls, {
		"settings",
		"skin",
		"timer",
		"notes",
		"metronome",
		"selection:0.5",
		"point:0.5",
		"timing:0.5",
		"audio",
		"cursor",
		"visuals",
	})
end

---@param t testing.T
function test.receive_frame_started_sets_timer(t)
	local setTime
	local context = {
		getTimer = function()
			return {
				setGlobalTime = function(_, time)
					setTime = time
				end,
			}
		end,
	}

	EditorModelFrameService():receive(context, {
		name = "framestarted",
		time = 1.25,
	})

	t:eq(setTime, 1.25)
end

---@param t testing.T
function test.receive_ignores_other_events(t)
	local called = false
	local context = {
		getTimer = function()
			return {
				setGlobalTime = function()
					called = true
				end,
			}
		end,
	}

	EditorModelFrameService():receive(context, {
		name = "other",
		time = 1.25,
	})

	t:eq(called, false)
end

return test
