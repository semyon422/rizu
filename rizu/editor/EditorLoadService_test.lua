local EditorLoadService = require("rizu.editor.EditorLoadService")

local test = {}

local function createContext(calls)
	local editor = {
		time = 1.25,
	}
	local audioSettings = {
		volume = {
			master = 0.5,
			music = 0.8,
			keysounds = 0.25,
		},
		mode = "mono",
	}
	local layer = {
		visuals = {
			main = {
				id = "main-visual",
			},
		},
	}
	local notes = {
		id = "notes",
	}
	local context
	context = {
		setLoaded = function(_, loaded)
			table.insert(calls, "loaded:" .. tostring(loaded))
		end,
		getSettings = function()
			table.insert(calls, "settings")
			return editor
		end,
		noteChartLoader = {
			load = function()
				table.insert(calls, "chart")
				return layer, notes
			end,
		},
		getNoteChartLoader = function()
			return context.noteChartLoader
		end,
		setChartData = function(_, loadedLayer, loadedNotes)
			table.insert(calls, "chart-data")
			context.layer = loadedLayer
			context.notes = loadedNotes
		end,
		setVisual = function(_, visual)
			table.insert(calls, "visual:" .. visual.id)
			context.visual = visual
		end,
		sessionResetService = {
			reset = function(_, sessionContext)
				table.insert(calls, "reset:" .. sessionContext.id)
			end,
		},
		getSessionResetService = function()
			return context.sessionResetService
		end,
		getSessionResetContext = function()
			return {
				id = "session",
			}
		end,
		playbackService = {
			loadTimer = function(_, timer, loadedEditor)
				table.insert(calls, "timer")
				timer:setTime(loadedEditor.time)
			end,
			loadAudio = function(_, audioEngine, loadedAudioSettings)
				table.insert(calls, "audio")
				audioEngine.settings = loadedAudioSettings
			end,
		},
		getPlaybackService = function()
			return context.playbackService
		end,
		timer = {
			time = 0,
			setTime = function(self, time)
				self.time = time
			end,
			getTime = function(self)
				table.insert(calls, "timer-time")
				return self.time
			end,
		},
		getTimer = function()
			return context.timer
		end,
		audio_engine = {},
		getAudioEngine = function()
			return context.audio_engine
		end,
		getAudioSettings = function()
			return audioSettings
		end,
		configModel = {
			configs = {
				settings = {
					audio = audioSettings,
				},
			},
		},
		getConfigModel = function()
			return context.configModel
		end,
		metronome = {
			load = function()
				table.insert(calls, "metronome")
			end,
		},
		getMetronome = function()
			return context.metronome
		end,
		scroller = {
			scrollSeconds = function(_, time)
				table.insert(calls, "scroll:" .. time)
			end,
		},
		getScroller = function()
			return context.scroller
		end,
		bmsToolsContext = {
			initFromLayer = function(_, loadedLayer)
				table.insert(calls, "bms")
				context.bmsLayer = loadedLayer
			end,
		},
		getBmsToolsContext = function()
			return context.bmsToolsContext
		end,
		metadata = {
			new = function()
				table.insert(calls, "metadata-new")
			end,
			fromChartmeta = function(_, chartmeta)
				table.insert(calls, "metadata:" .. chartmeta.title)
			end,
		},
		chartmeta = {
			title = "Title",
		},
		getMetadata = function()
			return context.metadata
		end,
		getChartmeta = function()
			return context.chartmeta
		end,
	}
	return context
end

---@param t testing.T
function test.load_runs_lifecycle_steps_in_order(t)
	local calls = {}
	local context = createContext(calls)

	EditorLoadService():load(context)

	t:eq(context.layer.visuals.main.id, "main-visual")
	t:eq(context.notes.id, "notes")
	t:eq(context.visual, context.layer.visuals.main)
	t:eq(context.metronome.volume, context.configModel.configs.settings.audio.volume)
	t:eq(context.bmsLayer, context.layer)
	t:tdeq(calls, {
		"loaded:true",
		"settings",
		"chart",
		"chart-data",
		"visual:main-visual",
		"reset:session",
		"timer",
		"audio",
		"metronome",
		"timer-time",
		"scroll:1.25",
		"bms",
		"metadata-new",
		"metadata:Title",
	})
end

---@param t testing.T
function test.load_falls_back_to_default_visual(t)
	local calls = {}
	local context = createContext(calls)
	local defaultVisual = {
		id = "default",
	}
	context.noteChartLoader.load = function()
		return {
			visuals = {
				[""] = defaultVisual,
			},
		}, {}
	end

	EditorLoadService():load(context)

	t:eq(context.visual, defaultVisual)
end

---@param t testing.T
function test.load_allows_missing_visual_to_surface(t)
	local calls = {}
	local context = createContext(calls)
	context.noteChartLoader.load = function()
		return {
			visuals = {},
		}, {}
	end
	context.setVisual = function(_, visual)
		context.visual = visual
	end

	EditorLoadService():load(context)

	t:eq(context.visual, nil)
end

---@param t testing.T
function test.load_fails_fast_and_keeps_current_loaded_semantics(t)
	local calls = {}
	local context = createContext(calls)
	context.playbackService.loadAudio = function()
		table.insert(calls, "audio")
		error("audio failed")
	end

	t:has_error(function()
		EditorLoadService():load(context)
	end)

	t:tdeq(calls, {
		"loaded:true",
		"settings",
		"chart",
		"chart-data",
		"visual:main-visual",
		"reset:session",
		"timer",
		"audio",
	})
end

---@param t testing.T
function test.load_metronome_sets_volume_before_loading(t)
	local calls = {}
	local context = createContext(calls)
	context.metronome.load = function()
		table.insert(calls, "metronome")
		error("metronome failed")
	end

	t:has_error(function()
		EditorLoadService():load(context)
	end)

	t:eq(context.metronome.volume, context.configModel.configs.settings.audio.volume)
end

return test
