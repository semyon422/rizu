local EditorModel = require("rizu.editor.EditorModel")
local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")
local EditorCursorState = require("rizu.editor.EditorCursorState")
local EditorRenderState = require("rizu.editor.EditorRenderState")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")
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
	local managers = {
		noteChartLoader = {},
		audio_engine = {},
		ncbtContext = {},
		intervalManager = {},
		graphsGenerator = {},
		editorChanges = {},
		timer = timer,
		noteManager = {},
		visualEngine = {},
		scroller = {},
		metronome = {},
		metadata = {},
		bmsToolsContext = {},
		session = {},
		loadService = {},
		sessionResetService = {},
		resourceLoadService = {},
		cursorState = EditorCursorState(),
		selectionState = EditorSelectionState(),
		renderState = EditorRenderState(),
		analysisState = EditorAnalysisState(),
		runtimeState = EditorRuntimeState(),
		viewState = EditorViewState(),
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
		noteChartLoader = managers.noteChartLoader,
		audio_engine = managers.audio_engine,
		ncbtContext = managers.ncbtContext,
		intervalManager = managers.intervalManager,
		graphsGenerator = managers.graphsGenerator,
		editorChanges = managers.editorChanges,
		timer = managers.timer,
		noteManager = managers.noteManager,
		visualEngine = managers.visualEngine,
		scroller = managers.scroller,
		metronome = managers.metronome,
		metadata = managers.metadata,
		bmsToolsContext = managers.bmsToolsContext,
		session = managers.session,
		loadService = managers.loadService,
		sessionResetService = managers.sessionResetService,
		resourceLoadService = managers.resourceLoadService,
		cursorState = managers.cursorState,
		selectionState = managers.selectionState,
		renderState = managers.renderState,
		analysisState = managers.analysisState,
		runtimeState = managers.runtimeState,
		viewState = managers.viewState,
	})

	t:eq(editorModel.configModel, configModel)
	t:eq(editorModel.resourceModel, resourceModel)
	t:eq(editorModel.noteManager, managers.noteManager)
	t:eq(editorModel.visualEngine, managers.visualEngine)
	t:eq(managers.noteChartLoader.editorModel, editorModel)
	t:eq(managers.ncbtContext.editorModel, editorModel)
	t:eq(managers.intervalManager.editorModel, editorModel)
	t:eq(managers.graphsGenerator.editorModel, editorModel)
	t:eq(managers.editorChanges.editorModel, editorModel)
	t:eq(managers.noteManager.editorModel, editorModel)
	t:eq(managers.visualEngine.editorModel, editorModel)
	t:eq(managers.scroller.editorModel, editorModel)
	t:eq(managers.metronome.editorModel, editorModel)
	t:eq(managers.bmsToolsContext.editorModel, editorModel)
	t:eq(configModel.editorModel, nil)
	t:eq(resourceModel.editorModel, nil)
	t:eq(input.editorModel, nil)
	t:eq(managers.audio_engine.editorModel, nil)
	t:eq(managers.timer.editorModel, nil)
	t:eq(managers.metadata.editorModel, nil)
	t:eq(managers.session.editorModel, nil)
	t:eq(managers.loadService.editorModel, nil)
	t:eq(managers.sessionResetService.editorModel, nil)
	t:eq(managers.resourceLoadService.editorModel, nil)
	t:eq(managers.cursorState.editorModel, nil)
	t:eq(managers.selectionState.editorModel, nil)
	t:eq(managers.renderState.editorModel, nil)
	t:eq(managers.analysisState.editorModel, nil)
	t:eq(managers.runtimeState.editorModel, nil)
	t:eq(managers.viewState.editorModel, nil)
	t:eq(editorModel.session.point, managers.cursorState:getPoint())
	t:eq(editorModel.session.selectRect, managers.selectionState:getRect())
	t:eq(editorModel.session.noteSkin, managers.renderState:getNoteSkin())
	t:eq(editorModel.session.patterns_analyzed, managers.analysisState:getPatternsAnalyzed())
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
		session = {
			point = cursorState:getPoint(),
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

	function editorModel:getNoteSkin()
		return self.session.noteSkin
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
		sessionResetService = {
			reset = function(_, model)
				table.insert(calls, "session-reset")
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

	t:eq(editorModel:isLoaded(), true)
	t:eq(editorModel.layer, layer)
	t:eq(editorModel.notes, notes)
	t:eq(editorModel:getVisual(), "main-visual")
	t:eq(editorModel.metronome.volume, volume)
	t:tdeq(calls, {
		"chart-load",
		"session-reset",
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
function test.load_chart_data_falls_back_to_default_visual(t)
	local defaultVisual = {}
	local layer = {
		visuals = {
			[""] = defaultVisual,
		},
	}
	local notes = {}
	---@type rizu.editor.EditorModel
	local editorModel = {
		noteChartLoader = {
			load = function()
				return layer, notes
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:loadChartData()

	t:eq(editorModel.layer, layer)
	t:eq(editorModel.notes, notes)
	t:eq(editorModel:getVisual(), defaultVisual)
end

---@param t testing.T
function test.load_chart_data_allows_missing_visual_to_surface(t)
	local layer = {
		visuals = {},
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		noteChartLoader = {
			load = function()
				return layer, {}
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	editorModel:loadChartData()

	t:eq(editorModel:getVisual(), nil)
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
		session = {
			point = {
				absoluteTime = 10,
			},
			noteSkin = {
				getInverseTimePosition = function(_, y)
					return y / 2
				end,
			},
		},
		getMousePosition = function()
			return 12, 8
		end,
	}
	setmetatable(editorModel, {__index = EditorModel})

	function editorModel:getNoteSkin()
		return self.session.noteSkin
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
		session = {
			noteSkin = {
				getInverseTimePosition = function(_, y)
					return y
				end,
				getTimePosition = function(_, time)
					return time * 10
				end,
			},
			point = {
				absoluteTime = 5,
			},
		},
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
		return self.session.noteSkin
	end

	function editorModel:getSettings()
		return {
			speed = 1,
		}
	end

	editorModel:selectStart()
	editorModel:updateSelectionRect({speed = 2}, editorModel.session.noteSkin, 6)
	editorModel:selectEnd()

	t:eq(editorModel.session.selectRect, nil)
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
			load = function(_, model, loadedResources)
				table.insert(calls, "resource")
				t:eq(model, editorModel)
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
function test.load_metronome_propagates_failure(t)
	local calls = {}
	local volume = {
		master = 1,
		metronome = 0.5,
	}
	---@type rizu.editor.EditorModel
	local editorModel = {
		configModel = {
			configs = {
				settings = {
					audio = {
						volume = volume,
					},
				},
			},
		},
		metronome = {
			load = function()
				table.insert(calls, "load")
				error("metronome failed")
			end,
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	t:has_error(function()
		editorModel:loadMetronome()
	end)

	t:eq(editorModel.metronome.volume, volume)
	t:tdeq(calls, {"load"})
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

	function editorModel:getTimelineRange()
		return -1, 4
	end

	editorModel:genGraphs()

	t:tdeq(calls, {"density:-1:4", "vertices:-1:4"})
end

---@param t testing.T
function test.get_first_last_time_includes_audio_start_before_first_point(t)
	---@type rizu.editor.EditorModel
	local editorModel = {
		audio_engine = {
			getStartTime = function()
				return -0.25
			end,
		},
		layer = {
			points = {
				getFirstPoint = function()
					return {
						tonumber = function()
							return 1
						end,
					}
				end,
				getLastPoint = function()
					return {
						tonumber = function()
							return 3
						end,
					}
				end,
			},
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	local firstTime, lastTime = editorModel:getFirstLastTime()

	t:eq(firstTime, -0.25)
	t:eq(lastTime, 3)
end

---@param t testing.T
function test.get_first_last_time_keeps_chart_start_when_audio_starts_later(t)
	---@type rizu.editor.EditorModel
	local editorModel = {
		audio_engine = {
			getStartTime = function()
				return 1.5
			end,
		},
		layer = {
			points = {
				getFirstPoint = function()
					return {
						tonumber = function()
							return 0
						end,
					}
				end,
				getLastPoint = function()
					return {
						tonumber = function()
							return 4
						end,
					}
				end,
			},
		},
	}
	setmetatable(editorModel, {__index = EditorModel})

	local firstTime, lastTime = editorModel:getTimelineRange()

	t:eq(firstTime, 0)
	t:eq(lastTime, 4)
end

return test
