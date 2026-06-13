local EditorModel = require("rizu.editor.EditorModel")
local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")
local EditorCursorState = require("rizu.editor.EditorCursorState")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")
local EditorRenderState = require("rizu.editor.EditorRenderState")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")
local EditorSelectionService = require("rizu.editor.EditorSelectionService")
local EditorSettingsService = require("rizu.editor.EditorSettingsService")
local EditorAnalysisService = require("rizu.editor.EditorAnalysisService")
local EditorRuntimeState = require("rizu.editor.EditorRuntimeState")
local EditorViewState = require("rizu.editor.EditorViewState")
local EditorModelContext = require("rizu.editor.EditorModelContext")

local test = {}
local createEditorModel
local attachEditorModel

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.EditorModel
function attachEditorModel(editorModel)
	setmetatable(editorModel, {__index = EditorModel})
	editorModel.context = EditorModelContext(editorModel)
	return editorModel
end

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
	t:eq(editorModel.analysisService, services.analysisService)
	t:eq(editorModel.visualEngine, services.visualEngine)
	t:eq(type(services.noteChartLoader.context.getChart), "function")
	t:eq(services.noteChartLoader.editorModel, nil)
	t:eq(services.ncbtContext.editorModel, nil)
	t:eq(type(services.intervalManager.context.getLayer), "function")
	t:eq(services.graphsGenerator.editorModel, nil)
	t:eq(type(services.editorChanges.context.resetVisual), "function")
	t:eq(services.editorChanges.editorModel, nil)
	t:eq(type(services.noteService.context.getSelectedNotes), "function")
	t:eq(services.noteService.context:getEditorChanges(), editorModel.editorChanges)
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
				context:setChartmeta({
					title = "Saved",
				})
			end,
		},
	}
	attachEditorModel(editorModel)

	editorModel:save()

	t:eq(savedContext:getMetadata(), editorModel.metadata)
	t:eq(savedContext:getNoteChartLoader(), editorModel.noteChartLoader)
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
				t:eq(context:getTimer(), editorModel.timer)
				t:eq(context:getAudioEngine(), editorModel.audio_engine)
			end,
			playEditor = function(_, context)
				table.insert(calls, "play")
				t:eq(context:getIntervalManager(), editorModel.intervalManager)
			end,
			pauseEditor = function(_, context)
				table.insert(calls, "pause")
				t:eq(context:getAudioEngine(), editorModel.audio_engine)
			end,
		},
	}
	attachEditorModel(editorModel)

	editorModel:setTime(1.25)
	editorModel:play()
	editorModel:pause()

	t:tdeq(calls, {
		"time:1.25",
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
				t:eq(context:getConfigModel(), editorModel.configModel)
				t:eq(context:getMaxSnap(), 64)
				t:eq(value, editor)
				return value
			end,
			getEditorSettings = function(_, context)
				table.insert(calls, "settings")
				t:eq(context:getConfigModel(), editorModel.configModel)
				t:eq(context:getMaxSnap(), 64)
				return editor
			end,
			getEditorAudioSettings = function(_, context)
				table.insert(calls, "audio")
				t:eq(context:getConfigModel(), editorModel.configModel)
				t:eq(context:getMaxSnap(), 64)
				return audio
			end,
			getEditorLogSpeed = function(_, context)
				table.insert(calls, "log")
				t:eq(context:getConfigModel(), editorModel.configModel)
				return 20
			end,
			setEditorLogSpeed = function(_, context, logSpeed)
				table.insert(calls, "setLog:" .. logSpeed)
				t:eq(context:getMaxSnap(), 64)
			end,
			incEditorSnap = function(_, context)
				table.insert(calls, "inc")
				t:eq(context:getConfigModel(), editorModel.configModel)
			end,
			decEditorSnap = function(_, context)
				table.insert(calls, "dec")
				t:eq(context:getMaxSnap(), 64)
			end,
			getEditorSnap = function(_, context, j)
				table.insert(calls, "snap:" .. j)
				t:eq(context:getConfigModel(), editorModel.configModel)
				return 8
			end,
		},
	}
	attachEditorModel(editorModel)

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
function test.history_commands_use_editor_changes(t)
	local calls = {}
	local editorChanges = {
		undo = function()
			table.insert(calls, "undo")
		end,
		redo = function()
			table.insert(calls, "redo")
		end,
	}
	---@type rizu.editor.EditorModel
	local editorModel = {editorChanges = editorChanges}
	attachEditorModel(editorModel)

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
		settingsService = EditorSettingsService(),
	}
	attachEditorModel(editorModel)
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
function test.update_delegates_to_frame_service_context(t)
	local calls = {}
	---@type rizu.editor.EditorModel
	local editorModel = {
		frameService = {
			update = function(_, context)
				table.insert(calls, "update")
				t:eq(type(context.getTimer), "function")
			end,
		},
	}
	attachEditorModel(editorModel)

	editorModel:update()

	t:tdeq(calls, {"update"})
end

---@param t testing.T
function test.load_delegates_to_load_service_context(t)
	local calls = {}
	---@type rizu.editor.EditorModel
	local editorModel = {
		loadService = {
			load = function(_, context)
				table.insert(calls, "load")
				t:eq(type(context.getNoteChartLoader), "function")
			end,
		},
	}
	attachEditorModel(editorModel)

	editorModel:load()

	t:tdeq(calls, {"load"})
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
	attachEditorModel(editorModel)
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
		selectionService = EditorSelectionService(),
		isMultiSelectRequested = function()
			return true
		end,
	}
	attachEditorModel(editorModel)

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
	attachEditorModel(editorModel)

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
		selectionService = EditorSelectionService(),
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
	attachEditorModel(editorModel)

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
		editorModel.context:getSelectionRectContext(),
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
	attachEditorModel(editorModel)

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
				t:eq(type(context.getPlaybackService), "function")
				t:eq(type(context.getPlaybackContext), "function")
				t:eq(type(context.getAnalysisService), "function")
				t:eq(type(context.getAnalysisContext), "function")
				t:eq(type(context.setResourcesLoaded), "function")
				t:eq(loadedResources, resources)
			end,
		},
	}
	attachEditorModel(editorModel)
	editorModel:setLoaded(true)

	editorModel:loadResources(resources)

	t:tdeq(calls, {"resource"})
end

---@param t testing.T
function test.resource_load_context_exposes_resource_collaborators(t)
	local resources = {
		audio = "song.ogg",
	}
	local wave = {}
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
				t:eq(loadedResources, resources)
				t:eq(playbackContext:getTimer(), editorModel.timer)
				t:eq(playbackContext:getAudioEngine(), editorModel.audio_engine)
				t:eq(playbackContext:getChart(), editorModel.chart)
				t:eq(playbackContext:getIntervalManager(), editorModel.intervalManager)
			end,
		},
		analysisService = {
			renderWave = function(_, analysisContext)
				t:eq(analysisContext:getAudioEngine(), editorModel.audio_engine)
				analysisContext:setWave(wave)
			end,
			genGraphs = function(_, analysisContext)
				t:eq(analysisContext:getChart(), editorModel.chart)
				t:eq(analysisContext:getGraphsGenerator(), editorModel.graphsGenerator)
			end,
		},
		graphsGenerator = {
			id = "graphs",
		},
	}
	attachEditorModel(editorModel)

	function editorModel:setResourcesLoaded(loaded)
		self.resourcesLoaded = loaded
	end

	local context = editorModel.context:getResourceLoadContext()
	context:getPlaybackService():loadEditorAudioResources(context:getPlaybackContext(), resources)
	context:getAnalysisService():renderWave(context:getAnalysisContext())
	context:getAnalysisService():genGraphs(context:getAnalysisContext())
	context:setResourcesLoaded(true)

	t:eq(editorModel:getWave(), wave)
	t:eq(editorModel.resourcesLoaded, true)
end

---@param t testing.T
function test.interval_manager_context_reads_current_model_state(t)
	local editorModel = {
		layer = {},
		notes = {},
		editorChanges = {},
	}
	attachEditorModel(editorModel)

	local context = editorModel.context:getIntervalManagerContext()
	t:eq(context:getLayer(), editorModel.layer)
	t:eq(context:getNotes(), editorModel.notes)
	t:eq(context:getEditorChanges(), editorModel.editorChanges)

	editorModel.layer = {updated = true}
	editorModel.notes = {updated = true}
	t:eq(context:getLayer(), editorModel.layer)
	t:eq(context:getNotes(), editorModel.notes)
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
	attachEditorModel(editorModel)

	local context = editorModel.context:getNoteServiceContext()

	t:eq(context:getNoteSkin(), "noteSkin")
	t:eq(context:getSelectedNotes(), editorModel.visualEngine.selectedNotes)
	t:eq(context:getEditorChanges(), editorModel.editorChanges)
	t:eq(context:getNoteOpsContext():getNotes(), editorModel.notes)
	t:eq(context:getMouseTime(), 1.25)
	t:eq(context:getPoint(), "point")
	t:eq(context:getVisualInfo(), editorModel.visualEngine.visual_info)
	t:eq(context:getEditorNoteContext():getLayer(), editorModel.layer)
end

---@param t testing.T
function test.graph_generation_uses_analysis_context(t)
	local calls = {}
	local chart = {
		id = "chart",
	}
	---@type rizu.editor.EditorModel
	local editorModel
	editorModel = {
		chart = chart,
		graphsGenerator = {
			id = "graphs",
		},
		analysisService = {
			genGraphs = function(_, context)
				table.insert(calls, "graphs")
					t:eq(context:getGraphsGenerator(), editorModel.graphsGenerator)
			end,
		},
	}
	attachEditorModel(editorModel)

	editorModel:genGraphs()

	t:tdeq(calls, {"graphs"})
end

return test
