local EditorModelFrameService = require("rizu.editor.EditorModelFrameService")

local test = {}

---@param t testing.T
function test.update_order(t)
	local calls = {}
	local editor = {}
	local noteSkin = {}
	local point = {}
	local context = {
		timer = {
			getTime = function()
				table.insert(calls, "timer")
				return 0.5
			end,
		},
		services = {
			update = function()
				table.insert(calls, "services")
			end,
		},
		selectionService = {
			updateSelectionRect = function(_, selectionContext, frameEditor, frameNoteSkin, time)
				table.insert(calls, "selection:" .. time)
				t:eq(selectionContext.id, "selection")
				t:eq(frameEditor, editor)
				t:eq(frameNoteSkin, noteSkin)
			end,
		},
		playbackService = {
			updateAudio = function(_, audioEngine)
				table.insert(calls, "audio")
				t:eq(audioEngine.id, "audio")
			end,
		},
		audio_engine = {
			id = "audio",
		},
		intervalManager = {
			grabbedVertex = true,
			moveGrabbed = function(_, time)
				table.insert(calls, "timing:" .. time)
			end,
		},
		visualEngine = {
			update = function()
				table.insert(calls, "visuals")
			end,
		},
		getSettings = function()
			table.insert(calls, "settings")
			return editor
		end,
		getNoteSkin = function()
			table.insert(calls, "skin")
			return noteSkin
		end,
		getDtpAbsolute = function(time)
			table.insert(calls, "point:" .. time)
			return point
		end,
		setSessionPoint = function(framePoint)
			table.insert(calls, "cursor")
			t:eq(framePoint, point)
		end,
		createSelectionRectContext = function()
			return {
				id = "selection",
			}
		end,
	}

	EditorModelFrameService():update(context)

	t:tdeq(calls, {
		"settings",
		"skin",
		"timer",
		"services",
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
		timer = {
			setGlobalTime = function(_, time)
				setTime = time
			end,
		},
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
		timer = {
			setGlobalTime = function()
				called = true
			end,
		},
	}

	EditorModelFrameService():receive(context, {
		name = "other",
		time = 1.25,
	})

	t:eq(called, false)
end

return test
