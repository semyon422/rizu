local EditorModel = require("rizu.editor.EditorModel")

local test = {}

---@return rizu.editor.EditorModel
local function createEditorModel()
	---@type rizu.editor.EditorModel
	local editorModel = {
		configModel = {
			configs = {
				settings = {
					editor = {
						speed = 0,
						snap = 999,
					},
				},
			},
		},
		session = {
			point = {},
		},
	}
	setmetatable(editorModel, {__index = EditorModel})
	return editorModel
end

---@param t testing.T
function test.get_settings_normalizes_speed_and_snap(t)
	local editorModel = createEditorModel()
	local editor = editorModel:getSettings()

	t:eq(editor.speed, 1)
	t:eq(editor.snap, EditorModel.max_snap)
end

---@param t testing.T
function test.set_session_point_clones_point(t)
	local editorModel = createEditorModel()
	local point = {
		absoluteTime = 1.25,
		clone = function(self, target)
			target.absoluteTime = self.absoluteTime
			target.cloned = true
		end,
	}

	editorModel:setSessionPoint(point)

	t:eq(editorModel:getSessionTime(), 1.25)
	t:eq(editorModel.session.point.cloned, true)
end

---@param t testing.T
function test.update_order(t)
	local calls = {}
	local editor = {
		speed = 1,
	}
	local point = {
		absoluteTime = 0.5,
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		session = {
			noteSkin = {},
		},
		timer = {
			getTime = function()
				table.insert(calls, "timer")
				return 0.5
			end,
		},
		noteManager = {
			update = function()
				table.insert(calls, "notes")
			end,
		},
		metronome = {
			update = function()
				table.insert(calls, "metronome")
			end,
		},
		intervalManager = {
			grabbedVertex = true,
			moveGrabbed = function(_, time)
				table.insert(calls, "timing:" .. time)
			end,
		},
		audio_engine = {
			update = function()
				table.insert(calls, "audio")
			end,
		},
		visualEngine = {
			update = function()
				table.insert(calls, "visuals")
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	function editorModel:getSettings()
		table.insert(calls, "settings")
		return editor
	end

	function editorModel:getDtpAbsolute(time)
		table.insert(calls, "point:" .. time)
		return point
	end

	function editorModel:setSessionPoint(sessionPoint)
		table.insert(calls, "session")
		t:eq(sessionPoint, point)
	end

	editorModel:update()

	t:eq(editor.time, 0.5)
	t:tdeq(calls, {
		"settings",
		"timer",
		"notes",
		"metronome",
		"point:0.5",
		"timing:0.5",
		"audio",
		"session",
		"visuals",
	})
end

---@param t testing.T
function test.load_initializes_editor_collaborators(t)
	local calls = {}
	local layer = {
		visuals = {
			main = "main-visual",
		},
	}
	local notes = {}
	local editor = {
		time = 1.25,
		speed = 1,
		snap = 4,
	}
	local volume = {
		master = 0.5,
		music = 0.8,
		keysounds = 0.25,
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		configModel = {
			configs = {
				settings = {
					editor = editor,
					audio = {
						volume = volume,
						mode = "mono",
					},
				},
			},
		},
		noteChartLoader = {
			load = function()
				table.insert(calls, "chart-load")
				return layer, notes
			end,
		},
		session = {
			load = function(_, model)
				table.insert(calls, "session-load")
				t:eq(model.chartmeta.title, "Title")
			end,
		},
		timer = {
			pause = function()
				table.insert(calls, "timer-pause")
			end,
			setTime = function(_, time)
				table.insert(calls, "timer-time:" .. time)
			end,
			getTime = function()
				table.insert(calls, "timer-get")
				return 1.25
			end,
		},
		audio_engine = {
			setVolume = function(_, music, keysounds)
				table.insert(calls, ("audio-volume:%s:%s"):format(music, keysounds))
			end,
			setAudioMode = function(_, mode)
				table.insert(calls, "audio-mode:" .. mode)
			end,
		},
		metronome = {
			load = function()
				table.insert(calls, "metronome-load")
			end,
		},
		scroller = {
			scrollSeconds = function(_, time)
				table.insert(calls, "scroll:" .. time)
			end,
		},
		bmsToolsContext = {
			initFromLayer = function(_, loadedLayer)
				table.insert(calls, "bms-init")
				t:eq(loadedLayer, layer)
			end,
		},
		metadata = {
			new = function()
				table.insert(calls, "metadata-new")
			end,
			fromChartmeta = function(_, chartmeta)
				table.insert(calls, "metadata-chartmeta")
				t:eq(chartmeta.title, "Title")
			end,
		},
		chartmeta = {
			title = "Title",
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:load()

	t:eq(editorModel.loaded, true)
	t:eq(editorModel.layer, layer)
	t:eq(editorModel.notes, notes)
	t:eq(editorModel.visual, "main-visual")
	t:eq(editorModel.metronome.volume, volume)
	t:tdeq(calls, {
		"chart-load",
		"session-load",
		"timer-pause",
		"timer-time:1.25",
		"audio-volume:0.4:0.125",
		"audio-mode:mono",
		"metronome-load",
		"timer-get",
		"scroll:1.25",
		"bms-init",
		"metadata-new",
		"metadata-chartmeta",
	})
end

---@param t testing.T
function test.unload_stops_runtime_resources(t)
	local calls = {}
	---@type rizu.editor.EditorModel
	local editorModel = {
		loaded = true,
		audio_engine = {
			unload = function()
				table.insert(calls, "audio")
			end,
		},
		metronome = {
			unload = function()
				table.insert(calls, "metronome")
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:unload()

	t:eq(editorModel.loaded, false)
	t:tdeq(calls, {"audio", "metronome"})
end

---@param t testing.T
function test.select_note_uses_injected_multi_select_predicate(t)
	local note = {
		id = "note",
	}
	local selectedNote
	local keepOthers
	---@type rizu.editor.EditorModel
	local editorModel = {
		visualEngine = {
			selectNote = function(_, visualNote, keep)
				selectedNote = visualNote
				keepOthers = keep
			end,
		},
		isMultiSelectRequested = function()
			return true
		end,
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:selectNote(note)

	t:eq(selectedNote, note)
	t:eq(keepOthers, true)
end

---@param t testing.T
function test.load_resources_ignored_when_not_loaded(t)
	local calls = {}
	---@type rizu.editor.EditorModel
	local editorModel = {
		loaded = false,
		audio_engine = {
			setEnabled = function()
				table.insert(calls, "audio")
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:loadResources({})

	t:tdeq(calls, {})
	t:eq(editorModel.resourcesLoaded, nil)
end

---@param t testing.T
function test.load_resources_loads_audio_wave_and_graphs(t)
	local calls = {}
	local chart = {
		id = "chart",
	}
	local resources = {
		audio = "song.ogg",
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		loaded = true,
		chart = chart,
		timer = {
			getTime = function()
				table.insert(calls, "timer")
				return 2.5
			end,
		},
		audio_engine = {
			setEnabled = function(_, enabled)
				table.insert(calls, "enabled:" .. tostring(enabled))
			end,
			load = function(_, loadedChart, loadedResources)
				table.insert(calls, "load")
				t:eq(loadedChart, chart)
				t:eq(loadedResources, resources)
			end,
			setPosition = function(_, time)
				table.insert(calls, "position:" .. time)
			end,
			renderWave = function()
				table.insert(calls, "wave")
				return "wave-data"
			end,
		},
		genGraphs = function(self)
			table.insert(calls, "graphs")
		end,
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:loadResources(resources)

	t:eq(editorModel.wave, "wave-data")
	t:eq(editorModel.resourcesLoaded, true)
	t:tdeq(calls, {"enabled:true", "load", "timer", "position:2.5", "wave", "graphs"})
end

---@param t testing.T
function test.gen_graphs_uses_first_last_time(t)
	local calls = {}
	local chart = {
		id = "chart",
	}
	local layer = {
		id = "layer",
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		chart = chart,
		layer = layer,
		graphsGenerator = {
			genDensityGraph = function(_, loadedChart, firstTime, lastTime)
				table.insert(calls, ("density:%s:%s"):format(firstTime, lastTime))
				t:eq(loadedChart, chart)
			end,
			genVerticesGraph = function(_, loadedLayer, firstTime, lastTime)
				table.insert(calls, ("vertices:%s:%s"):format(firstTime, lastTime))
				t:eq(loadedLayer, layer)
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	function editorModel:getFirstLastTime()
		return -1, 4
	end

	editorModel:genGraphs()

	t:tdeq(calls, {"density:-1:4", "vertices:-1:4"})
end

return test
