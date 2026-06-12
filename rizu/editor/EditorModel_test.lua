local EditorModel = require("rizu.editor.EditorModel")
local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")
local EditorCursorState = require("rizu.editor.EditorCursorState")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")
local EditorRenderState = require("rizu.editor.EditorRenderState")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")
local EditorSelectionService = require("rizu.editor.EditorSelectionService")
local EditorSettingsService = require("rizu.editor.EditorSettingsService")
local EditorHistoryService = require("rizu.editor.EditorHistoryService")
local EditorAnalysisService = require("rizu.editor.EditorAnalysisService")
local EditorRuntimeState = require("rizu.editor.EditorRuntimeState")
local EditorViewState = require("rizu.editor.EditorViewState")

local test = {}
local createEditorModel

---@param t testing.T
function test.new_uses_dependency_table_and_input_adapter(t)
	local configModel = {
		configs = {
			settings = {
				editor = {
					speed = 1,
					snap = 4,
				},
			},
		},
	}
	local resourceModel = {}
	local timer = {
		setGlobalTime = function(_, time)
			t:eq(time, 0)
		end,
	}
	local scroller = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local intervalManager = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local metronome = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local editorChanges = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local noteChartLoader = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local visualEngine = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local noteService = {
		setContext = function(self, context)
			self.context = context
		end,
	}
	local services = {
		noteChartLoader = noteChartLoader,
		audio_engine = {},
		ncbtContext = {},
		intervalManager = intervalManager,
		graphsGenerator = {},
		editorChanges = editorChanges,
		timer = timer,
		noteService = noteService,
		visualEngine = visualEngine,
		scroller = scroller,
		metronome = metronome,
		metadata = {},
		bmsToolsContext = {},
		loadService = {},
		saveService = {},
		sessionResetService = {},
		resourceLoadService = {},
		playbackService = EditorPlaybackService(),
		selectionService = EditorSelectionService(),
		settingsService = EditorSettingsService(),
		historyService = EditorHistoryService(),
		analysisService = EditorAnalysisService(),
		cursorState = EditorCursorState(),
		selectionState = EditorSelectionState(),
		renderState = EditorRenderState(),
		analysisState = EditorAnalysisState(),
		runtimeState = EditorRuntimeState(),
		viewState = EditorViewState(),
		frameService = {},
	}
	local inputCalls = {}
	local input = {
		isMultiSelectRequested = function()
			table.insert(inputCalls, "multi")
			return true
		end,
		getMousePosition = function()
			table.insert(inputCalls, "mouse")
			return 7, 11
		end,
		selectRegion = function(_, x1, y1, x2, y2)
			table.insert(inputCalls, ("select:%s:%s:%s:%s"):format(x1, y1, x2, y2))
		end,
		unselectRegion = function()
			table.insert(inputCalls, "unselect")
		end,
		isEditorCommandRequested = function()
			table.insert(inputCalls, "command")
			return true
		end,
		isFineScrollRequested = function()
			table.insert(inputCalls, "fine")
			return true
		end,
		isSnapChangeRequested = function()
			table.insert(inputCalls, "snap")
			return true
		end,
		isSpeedChangeRequested = function()
			table.insert(inputCalls, "speed")
			return true
		end,
	}

	local editorModel = EditorModel({
		configModel = configModel,
		resourceModel = resourceModel,
		input = input,
		noteChartLoader = services.noteChartLoader,
		audio_engine = services.audio_engine,
		ncbtContext = services.ncbtContext,
		intervalManager = services.intervalManager,
		graphsGenerator = services.graphsGenerator,
		editorChanges = services.editorChanges,
		timer = services.timer,
		noteService = services.noteService,
		visualEngine = services.visualEngine,
		scroller = services.scroller,
		metronome = services.metronome,
		metadata = services.metadata,
		bmsToolsContext = services.bmsToolsContext,
		loadService = services.loadService,
		saveService = services.saveService,
		sessionResetService = services.sessionResetService,
		resourceLoadService = services.resourceLoadService,
		playbackService = services.playbackService,
		selectionService = services.selectionService,
		settingsService = services.settingsService,
		historyService = services.historyService,
		analysisService = services.analysisService,
		cursorState = services.cursorState,
		selectionState = services.selectionState,
		renderState = services.renderState,
		analysisState = services.analysisState,
		runtimeState = services.runtimeState,
		viewState = services.viewState,
		frameService = services.frameService,
	})

	t:eq(editorModel.configModel, configModel)
	t:eq(editorModel.resourceModel, resourceModel)
	t:eq(editorModel.services.noteService, services.noteService)
	t:eq(editorModel.services.metronome, services.metronome)
	t:eq(editorModel.services.frameService, services.frameService)
	t:eq(editorModel.noteService, services.noteService)
	t:eq(editorModel.saveService, services.saveService)
	t:eq(editorModel.frameService, services.frameService)
	t:eq(editorModel.historyService, services.historyService)
	t:eq(editorModel.analysisService, services.analysisService)
	t:eq(editorModel.visualEngine, services.visualEngine)
	t:eq(type(services.noteChartLoader.context.getChart), "function")
	t:eq(services.noteChartLoader.editorModel, nil)
	t:eq(services.ncbtContext.editorModel, nil)
	t:eq(type(services.intervalManager.context.getLayer), "function")
	t:eq(services.graphsGenerator.editorModel, nil)
	t:eq(type(services.editorChanges.context.resetVisual), "function")
	t:eq(services.editorChanges.editorModel, nil)
	t:eq(type(services.noteService.context.commandService.getSelectedNotes), "function")
	t:eq(services.noteService.context.commandService.editorChanges, editorModel.editorChanges)
	t:eq(services.noteService.editorModel, nil)
	t:eq(type(services.visualEngine.context.getNotes), "function")
	t:eq(services.visualEngine.editorModel, nil)
	t:eq(type(services.scroller.context.getPoint), "function")
	t:eq(type(services.metronome.context.getPoint), "function")
	t:eq(services.bmsToolsContext.editorModel, nil)
	t:eq(configModel.editorModel, nil)
	t:eq(resourceModel.editorModel, nil)
	t:eq(input.editorModel, nil)
	t:eq(services.audio_engine.editorModel, nil)
	t:eq(services.timer.editorModel, nil)
	t:eq(services.metadata.editorModel, nil)
	t:eq(services.loadService.editorModel, nil)
	t:eq(services.saveService.editorModel, nil)
	t:eq(services.sessionResetService.editorModel, nil)
	t:eq(services.resourceLoadService.editorModel, nil)
	t:eq(services.playbackService.editorModel, nil)
	t:eq(services.selectionService.editorModel, nil)
	t:eq(services.settingsService.editorModel, nil)
	t:eq(services.historyService.editorModel, nil)
	t:eq(services.analysisService.editorModel, nil)
	t:eq(services.cursorState.editorModel, nil)
	t:eq(services.selectionState.editorModel, nil)
	t:eq(services.renderState.editorModel, nil)
	t:eq(services.analysisState.editorModel, nil)
	t:eq(services.runtimeState.editorModel, nil)
	t:eq(services.viewState.editorModel, nil)
	t:eq(services.frameService.editorModel, nil)
	t:eq(editorModel:getPoint(), services.cursorState:getPoint())
	t:eq(editorModel:getSelectionState(), services.selectionState)
	t:eq(editorModel:getNoteSkin(), services.renderState:getNoteSkin())
	t:eq(editorModel:getPatternsAnalyzed(), services.analysisState:getPatternsAnalyzed())
	t:eq(editorModel.isMultiSelectRequested(), true)
	t:eq(editorModel.isEditorCommandRequested(), true)
	t:eq(editorModel.isFineScrollRequested(), true)
	t:eq(editorModel.isSnapChangeRequested(), true)
	t:eq(editorModel.isSpeedChangeRequested(), true)
	local mx, my = editorModel.getMousePosition()
	editorModel.selectRegion(1, 2, 3, 4)
	editorModel.unselectRegion()

	t:eq(mx, 7)
	t:eq(my, 11)
	t:tdeq(inputCalls, {
		"multi",
		"command",
		"fine",
		"snap",
		"speed",
		"mouse",
		"select:1:2:3:4",
		"unselect",
	})
end

---@param t testing.T
function test.save_delegates_to_save_service_context(t)
	local savedContext
	local editorModel = {
		metadata = {
			id = "metadata",
		},
		noteChartLoader = {
			id = "loader",
		},
		saveService = {
			save = function(_, context)
				savedContext = context
				context.setChartmeta({
					title = "Saved",
				})
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:save()

	t:eq(savedContext.metadata, editorModel.metadata)
	t:eq(savedContext.noteChartLoader, editorModel.noteChartLoader)
	t:eq(editorModel.chartmeta.title, "Saved")
end

---@param t testing.T
function test.runtime_state_methods_use_runtime_state(t)
	local editorModel = createEditorModel()
	local visual = {}
	local wave = {}
	local changes = {}

	editorModel:setLoaded(true)
	editorModel:setResourcesLoaded(true)
	editorModel:setVisual(visual)
	editorModel:setWave(wave)
	editorModel:setChanges(changes)

	t:eq(editorModel:isLoaded(), true)
	t:eq(editorModel:isResourcesLoaded(), true)
	t:eq(editorModel:getVisual(), visual)
	t:eq(editorModel:getWave(), wave)
	t:eq(editorModel:getChanges(), changes)
	t:eq(editorModel:getRuntimeState():getVisual(), visual)
	t:eq(editorModel:getRuntimeState():getWave(), wave)
	t:eq(editorModel:getRuntimeState():getChanges(), changes)
end

---@param t testing.T
function test.get_preview_time_normalizes_chartmeta_value(t)
	local editorModel = createEditorModel()
	editorModel.chartmeta = {
		preview_time = "12.5",
	}

	t:eq(editorModel:getPreviewTime(), 12.5)
end

---@param t testing.T
function test.playback_commands_use_playback_context(t)
	local calls = {}
	---@type rizu.editor.EditorModel
	local editorModel
	editorModel = {
		timer = {
			id = "timer",
		},
		audio_engine = {
			id = "audio",
		},
		chart = {
			id = "chart",
		},
		intervalManager = {
			id = "intervals",
		},
		playbackService = {
			setEditorTime = function(_, context, time)
				table.insert(calls, "time:" .. time)
				t:eq(context.timer, editorModel.timer)
				t:eq(context.audio_engine, editorModel.audio_engine)
			end,
			loadEditorAudioResources = function(_, context, resources)
				table.insert(calls, "resources:" .. resources.audio)
				t:eq(context.chart, editorModel.chart)
			end,
			playEditor = function(_, context)
				table.insert(calls, "play")
				t:eq(context.intervalManager, editorModel.intervalManager)
			end,
			pauseEditor = function(_, context)
				table.insert(calls, "pause")
				t:eq(context.audio_engine, editorModel.audio_engine)
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:setTime(1.25)
	editorModel:loadAudioResources({audio = "song.ogg"})
	editorModel:play()
	editorModel:pause()

	t:tdeq(calls, {
		"time:1.25",
		"resources:song.ogg",
		"play",
		"pause",
	})
end

---@param t testing.T
function test.settings_commands_use_settings_context(t)
	local calls = {}
	local editor = {
		speed = 1,
		snap = 4,
	}
	local audio = {
		mode = "stereo",
	}
	---@type rizu.editor.EditorModel
	local editorModel
	editorModel = {
		configModel = {
			configs = {
				settings = {
					editor = editor,
					audio = audio,
				},
			},
		},
		max_snap = 64,
		settingsService = {
			normalizeContextEditorSettings = function(_, context, value)
				table.insert(calls, "normalize")
				t:eq(context.configModel, editorModel.configModel)
				t:eq(context.maxSnap, 64)
				t:eq(value, editor)
				return value
			end,
			getEditorSettings = function(_, context)
				table.insert(calls, "settings")
				t:eq(context.configModel, editorModel.configModel)
				t:eq(context.maxSnap, 64)
				return editor
			end,
			getEditorAudioSettings = function(_, context)
				table.insert(calls, "audio")
				t:eq(context.configModel, editorModel.configModel)
				t:eq(context.maxSnap, 64)
				return audio
			end,
			getEditorLogSpeed = function(_, context)
				table.insert(calls, "log")
				t:eq(context.configModel, editorModel.configModel)
				return 20
			end,
			setEditorLogSpeed = function(_, context, logSpeed)
				table.insert(calls, "setLog:" .. logSpeed)
				t:eq(context.maxSnap, 64)
			end,
			incEditorSnap = function(_, context)
				table.insert(calls, "inc")
				t:eq(context.configModel, editorModel.configModel)
			end,
			decEditorSnap = function(_, context)
				table.insert(calls, "dec")
				t:eq(context.maxSnap, 64)
			end,
			getEditorSnap = function(_, context, j)
				table.insert(calls, "snap:" .. j)
				t:eq(context.configModel, editorModel.configModel)
				return 8
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	t:eq(editorModel:normalizeEditorSettings(editor), editor)
	t:eq(editorModel:getSettings(), editor)
	t:eq(editorModel:getAudioSettings(), audio)
	t:eq(editorModel:getLogSpeed(), 20)
	editorModel:setLogSpeed(12)
	editorModel:incSnap()
	editorModel:decSnap()
	t:eq(editorModel:getSnap(3), 8)

	t:tdeq(calls, {
		"normalize",
		"settings",
		"audio",
		"log",
		"setLog:12",
		"inc",
		"dec",
		"snap:3",
	})
end

---@param t testing.T
function test.history_commands_use_history_context(t)
	local calls = {}
	local editorChanges = {
		id = "changes",
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		editorChanges = editorChanges,
		historyService = {
			undo = function(_, context)
				table.insert(calls, "undo")
				t:eq(context.editorChanges, editorChanges)
			end,
			redo = function(_, context)
				table.insert(calls, "redo")
				t:eq(context.editorChanges, editorChanges)
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:undo()
	editorModel:redo()

	t:tdeq(calls, {"undo", "redo"})
end

---@return rizu.editor.EditorModel
function createEditorModel()
	local cursorState = EditorCursorState()
	local selectionState = EditorSelectionState()
	local renderState = EditorRenderState()
	local analysisState = EditorAnalysisState()
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
		cursorState = cursorState,
		selectionState = selectionState,
		renderState = renderState,
		analysisState = analysisState,
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
	t:eq(editorModel:getPoint().cloned, true)
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
		noteSkin = {},
		timer = {
			getTime = function()
				table.insert(calls, "timer")
				return 0.5
			end,
		},
		noteService = {
			update = function()
				table.insert(calls, "notes")
			end,
		},
		metronome = {
			update = function()
				table.insert(calls, "metronome")
			end,
		},
		selectionService = {
			updateSelectionRect = function() end,
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

	function editorModel:getNoteSkin()
		return self.noteSkin
	end

	function editorModel:getSettings()
		table.insert(calls, "settings")
		return editor
	end

	function editorModel:getDtpAbsolute(time)
		table.insert(calls, "point:" .. time)
		return point
	end

	function editorModel:setSessionPoint(sessionPoint)
		table.insert(calls, "cursor")
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
		"cursor",
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
		sessionResetService = {
			reset = function(_, context)
				table.insert(calls, "state-reset")
				t:eq(type(context.analyzePatterns), "function")
				t:eq(type(context.newChanges), "function")
				t:eq(type(context.setChanges), "function")
				t:eq(type(context.loadGraphs), "function")
				t:eq(type(context.setResourcesLoaded), "function")
				t:eq(type(context.setSessionTime), "function")
				t:eq(type(context.finishSelection), "function")
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

	t:eq(editorModel:isLoaded(), true)
	t:eq(editorModel.layer, layer)
	t:eq(editorModel.notes, notes)
	t:eq(editorModel:getVisual(), "main-visual")
	t:eq(editorModel.metronome.volume, volume)
	t:tdeq(calls, {
		"chart-load",
		"state-reset",
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
	editorModel:setLoaded(true)

	editorModel:unload()

	t:eq(editorModel:isLoaded(), false)
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
function test.get_mouse_time_uses_injected_mouse_position(t)
	---@type rizu.editor.EditorModel
	local editorModel = {
		noteSkin = {
			getInverseTimePosition = function(_, y)
				return y / 2
			end,
		},
		getMousePosition = function()
			return 12, 8
		end,
	}
	setmetatable(editorModel, {__index = EditorModel})

	function editorModel:getNoteSkin()
		return self.noteSkin
	end

	function editorModel:getSessionTime()
		return 10
	end

	function editorModel:getSettings()
		return {
			speed = 2,
		}
	end

	t:eq(editorModel:getMouseTime(4), 7)
end

---@param t testing.T
function test.selection_region_uses_injected_callbacks(t)
	local calls = {}
	---@type rizu.editor.EditorModel
	local editorModel = {
		noteSkin = {
			getInverseTimePosition = function(_, y)
				return y
			end,
			getTimePosition = function(_, time)
				return time * 10
			end,
		},
		selectionState = EditorSelectionState(),
		visualEngine = {
			selectStart = function()
				table.insert(calls, "visual-start")
			end,
			selectEnd = function()
				table.insert(calls, "visual-end")
			end,
		},
		getMousePosition = function()
			return 3, 4
		end,
		selectRegion = function(x1, y1, x2, y2)
			table.insert(calls, ("select:%s:%s:%s:%s"):format(x1, y1, x2, y2))
		end,
		unselectRegion = function()
			table.insert(calls, "unselect")
		end,
	}
	setmetatable(editorModel, {__index = EditorModel})

	function editorModel:getNoteSkin()
		return self.noteSkin
	end

	function editorModel:getSessionTime()
		return 5
	end

	function editorModel:getSettings()
		return {
			speed = 1,
		}
	end

	editorModel:selectStart()
	EditorSelectionService():updateSelectionRect(
		editorModel:createSelectionRectContext(),
		{speed = 2},
		editorModel:getNoteSkin(),
		6
	)
	editorModel:selectEnd()

	t:eq(editorModel:getSelectionState():getRect(), nil)
	t:tdeq(calls, {
		"visual-start",
		"select:3:4:3:4",
		"select:3:100:3:4",
		"visual-end",
		"unselect",
	})
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
	t:eq(editorModel:isResourcesLoaded(), false)
end

---@param t testing.T
function test.load_resources_delegates_when_loaded(t)
	local calls = {}
	local resources = {
		audio = "song.ogg",
	}
	---@type rizu.editor.EditorModel
	local editorModel
	editorModel = {
		resourceLoadService = {
			load = function(_, context, loadedResources)
				table.insert(calls, "resource")
				t:eq(type(context.loadAudioResources), "function")
				t:eq(type(context.renderWave), "function")
				t:eq(type(context.genGraphs), "function")
				t:eq(type(context.setResourcesLoaded), "function")
				t:eq(loadedResources, resources)
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})
	editorModel:setLoaded(true)

	editorModel:loadResources(resources)

	t:tdeq(calls, {"resource"})
end

---@param t testing.T
function test.resource_load_context_delegates_to_services_and_model_methods(t)
	local calls = {}
	local resources = {
		audio = "song.ogg",
	}
	---@type rizu.editor.EditorModel
	local editorModel
	editorModel = {
		timer = {
			id = "timer",
		},
		audio_engine = {
			id = "audio",
		},
		chart = {
			id = "chart",
		},
		intervalManager = {
			id = "intervals",
		},
		playbackService = {
			loadEditorAudioResources = function(_, playbackContext, loadedResources)
				table.insert(calls, "audio:" .. loadedResources.audio)
				t:eq(playbackContext.timer, editorModel.timer)
				t:eq(playbackContext.audio_engine, editorModel.audio_engine)
				t:eq(playbackContext.chart, editorModel.chart)
				t:eq(playbackContext.intervalManager, editorModel.intervalManager)
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	function editorModel:renderWave()
		table.insert(calls, "wave")
	end

	function editorModel:genGraphs()
		table.insert(calls, "graphs")
	end

	function editorModel:setResourcesLoaded(loaded)
		table.insert(calls, "loaded:" .. tostring(loaded))
	end

	local context = editorModel:createResourceLoadContext()
	context.loadAudioResources(resources)
	context.renderWave()
	context.genGraphs()
	context.setResourcesLoaded(true)

	t:tdeq(calls, {
		"audio:song.ogg",
		"wave",
		"graphs",
		"loaded:true",
	})
end

---@param t testing.T
function test.interval_manager_context_reads_current_model_state(t)
	local editorModel = {
		layer = {},
		notes = {},
		editorChanges = {},
	}
	setmetatable(editorModel, {__index = EditorModel})

	local context = editorModel:createIntervalManagerContext()
	t:eq(context.getLayer(), editorModel.layer)
	t:eq(context.getNotes(), editorModel.notes)
	t:eq(context.editorChanges, editorModel.editorChanges)

	editorModel.layer = {updated = true}
	editorModel.notes = {updated = true}
	t:eq(context.getLayer(), editorModel.layer)
	t:eq(context.getNotes(), editorModel.notes)
end

---@param t testing.T
function test.editor_note_service_context_reads_current_model_state(t)
	local editorModel = {
		layer = {},
		notes = {},
		editorChanges = {},
		visualEngine = {
			selectedNotes = {},
			visual_info = {},
			reset = function() end,
			selectNote = function() end,
		},
		scroller = {
			getNextSnapIntervalTime = function()
				return "vertex", "time"
			end,
		},
		getMousePosition = function()
			return 10, 20
		end,
		getNoteSkin = function()
			return "noteSkin"
		end,
		getSettings = function()
			return "settings"
		end,
		getMouseTime = function()
			return 1.25
		end,
		getPoint = function()
			return "point"
		end,
		getVisual = function()
			return "visual"
		end,
		getDtpAbsolute = function(_, absoluteTime)
			return "dtp:" .. absoluteTime
		end,
	}
	setmetatable(editorModel, {__index = EditorModel})

	local context = editorModel:createEditorNoteServiceContext()

	t:eq(context.columnService.getNoteSkin(), "noteSkin")
	t:eq(context.commandService.getSelectedNotes(), editorModel.visualEngine.selectedNotes)
	t:eq(context.commandService.editorChanges, editorModel.editorChanges)
	t:eq(context.commandService.getNoteOpsContext().notes, editorModel.notes)
	t:eq(context.dragService.getMouseTime(), 1.25)
	t:eq(context.clipboardService.getPoint(), "point")
	t:eq(context.createService.getVisualInfo(), editorModel.visualEngine.visual_info)
	t:eq(context.createService.getEditorNoteContext().getLayer(), editorModel.layer)
end

---@param t testing.T
function test.analysis_commands_use_analysis_context(t)
	local calls = {}
	local chart = {
		id = "chart",
	}
	local layer = {
		id = "layer",
	}
	local wave = {
		id = "wave",
	}
	---@type rizu.editor.EditorModel
	local editorModel
	editorModel = {
		ncbtContext = {
			id = "ncbt",
		},
		audio_engine = {
			id = "audio",
		},
		chart = chart,
		layer = layer,
		graphsGenerator = {
			id = "graphs",
		},
		analysisService = {
			detectTempoOffset = function(_, context)
				table.insert(calls, "detect")
				t:eq(context.ncbtContext, editorModel.ncbtContext)
				t:eq(context.audio_engine, editorModel.audio_engine)
			end,
			applyNcbt = function(_, context)
				table.insert(calls, "apply")
				t:eq(context.layer, layer)
			end,
			renderWave = function(_, context)
				table.insert(calls, "wave")
				t:eq(context.audio_engine, editorModel.audio_engine)
				context.setWave(wave)
			end,
			getFirstLastTime = function(_, context)
				table.insert(calls, "firstLast")
				t:eq(context.layer, layer)
				return -1, 4
			end,
			getTimelineRange = function(_, context)
				table.insert(calls, "timeline")
				t:eq(context.chart, chart)
				return -2, 5
			end,
			genGraphs = function(_, context)
				table.insert(calls, "graphs")
				t:eq(context.graphsGenerator, editorModel.graphsGenerator)
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:detectTempoOffset()
	editorModel:applyNcbt()
	editorModel:renderWave()
	local firstTime, lastTime = editorModel:getFirstLastTime()
	local timelineStart, timelineEnd = editorModel:getTimelineRange()
	editorModel:genGraphs()

	t:eq(editorModel:getWave(), wave)
	t:eq(firstTime, -1)
	t:eq(lastTime, 4)
	t:eq(timelineStart, -2)
	t:eq(timelineEnd, 5)
	t:tdeq(calls, {"detect", "apply", "wave", "firstLast", "timeline", "graphs"})
end

return test
