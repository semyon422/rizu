local EditorLoadService = require("rizu.editor.EditorLoadService")

local test = {}

---@param t testing.T
function test.load_runs_lifecycle_steps_in_order(t)
	local calls = {}
	local editor = {
		speed = 1,
	}
	local loaded
	local context = {
		setLoaded = function(nextLoaded)
			loaded = nextLoaded
		end,
		getSettings = function()
			table.insert(calls, "settings")
			return editor
		end,
		loadChartData = function()
			table.insert(calls, "chart")
		end,
		resetState = function()
			table.insert(calls, "reset")
		end,
		loadTimer = function(loadedEditor)
			table.insert(calls, "timer")
			t:eq(loadedEditor, editor)
		end,
		loadAudio = function()
			table.insert(calls, "audio")
		end,
		loadMetronome = function()
			table.insert(calls, "metronome")
		end,
		loadInitialScroll = function()
			table.insert(calls, "scroll")
		end,
		loadBmsToolsContext = function()
			table.insert(calls, "bms")
		end,
		loadMetadata = function()
			table.insert(calls, "metadata")
		end,
	}

	EditorLoadService():load(context)

	t:eq(loaded, true)
	t:tdeq(calls, {
		"settings",
		"chart",
		"reset",
		"timer",
		"audio",
		"metronome",
		"scroll",
		"bms",
		"metadata",
	})
end

---@param t testing.T
function test.load_fails_fast_and_keeps_current_loaded_semantics(t)
	local calls = {}
	local loaded
	local context = {
		setLoaded = function(nextLoaded)
			loaded = nextLoaded
		end,
		getSettings = function()
			table.insert(calls, "settings")
			return {}
		end,
		loadChartData = function()
			table.insert(calls, "chart")
		end,
		resetState = function()
			table.insert(calls, "reset")
		end,
		loadTimer = function()
			table.insert(calls, "timer")
		end,
		loadAudio = function()
			table.insert(calls, "audio")
			error("audio failed")
		end,
		loadMetronome = function()
			table.insert(calls, "metronome")
		end,
		loadInitialScroll = function()
			table.insert(calls, "scroll")
		end,
		loadBmsToolsContext = function()
			table.insert(calls, "bms")
		end,
		loadMetadata = function()
			table.insert(calls, "metadata")
		end,
	}

	t:has_error(function()
		EditorLoadService():load(context)
	end)

	t:eq(loaded, true)
	t:tdeq(calls, {"settings", "chart", "reset", "timer", "audio"})
end

return test
