local EditorModelContext = require("rizu.editor.EditorModelContext")

local test = {}

---@param t testing.T
function test.aggregate_exposes_focused_contexts(t)
	local context = EditorModelContext({})

	t:eq(context:getLoadContext(), context:getDataContext())
	t:eq(context:getSaveContext(), context:getDataContext())
	t:eq(context:getResourceLoadContext(), context:getDataContext())
	t:eq(context:getAnalysisContext(), context:getDataContext())
	t:eq(context:getNoteChartLoaderContext(), context:getDataContext())
	t:eq(context:getIntervalManagerContext(), context:getDataContext())

	t:eq(context:getPlaybackContext(), context:getTimelineContext())
	t:eq(context:getScrollerContext(), context:getTimelineContext())
	t:eq(context:getMetronomeContext(), context:getTimelineContext())

	t:eq(context:getSettingsContext(), context:getViewContext())
	t:eq(context:getSelectionRectContext(), context:getViewContext())
	t:eq(context:getFrameContext(), context:getViewContext())
	t:eq(context:getVisualEngineContext(), context:getViewContext())
	t:eq(context:getEditorChangesContext(), context:getViewContext())
	t:eq(context:getNoteServiceContext(), context:getNoteEditContext())
end

---@param t testing.T
function test.data_context_reads_current_model_state(t)
	local model = {
		layer = {
			id = "layer-1",
		},
		chart = {
			id = "chart-1",
		},
		editorChanges = {
			id = "changes",
		},
	}
	local context = EditorModelContext(model):getDataContext()

	t:eq(context:getLayer().id, "layer-1")
	t:eq(context:getChart().id, "chart-1")
	t:eq(context:getEditorChanges(), model.editorChanges)

	model.layer = {
		id = "layer-2",
	}
	model.chart = {
		id = "chart-2",
	}

	t:eq(context:getLayer().id, "layer-2")
	t:eq(context:getChart().id, "chart-2")
end

---@param t testing.T
function test.view_context_delegates_to_model(t)
	local calls = {}
	local model
	model = {
		max_snap = 192,
		tools = {
			"Select",
			"ShortNote",
		},
		configModel = {
			configs = {
				settings = {
					editor = "editor",
					audio = "audio",
				},
			},
		},
		visualEngine = {
			selectedNotes = {
				id = "selected",
			},
			visual_info = {
				id = "visualInfo",
			},
			reset = function()
				table.insert(calls, "reset")
			end,
			selectNote = function(_, note)
				table.insert(calls, "selectNote:" .. tostring(note))
			end,
		},
		getSelectionState = function()
			return "selection"
		end,
		getSettings = function()
			table.insert(calls, "settings")
			return "settings"
		end,
		getNoteSkin = function()
			table.insert(calls, "noteSkin")
			return "noteSkin"
		end,
		getWave = function()
			return "wave"
		end,
		getLogSpeed = function()
			return 12
		end,
		setLogSpeed = function(_, logSpeed)
			table.insert(calls, "log-speed:" .. logSpeed)
		end,
		getVisual = function()
			return {
				getPoint = function(_, point)
					table.insert(calls, "visual-point:" .. point.id)
					return "visualPoint"
				end,
			}
		end,
		getMousePosition = function()
			table.insert(calls, "mouse")
			return 3, 4
		end,
		getMouseTime = function()
			return 1.25
		end,
		getPoint = function()
			return {
				absoluteTime = 2.5,
			}
		end,
		selectRegion = function(x1, y1, x2, y2)
			table.insert(calls, ("select:%s:%s:%s:%s"):format(x1, y1, x2, y2))
		end,
		unselectRegion = function()
			table.insert(calls, "unselect")
		end,
		analysisService = {
			id = "analysis",
			getTimelineRange = function(_, analysisContext)
				table.insert(calls, "timeline")
				t:eq(analysisContext, model.context:getAnalysisContext())
				return 1, 5
			end,
		},
		ncbtContext = {
			id = "ncbt",
		},
		graphsGenerator = {
			densityGraph = {
				id = "density",
			},
			vertexDatasGraph = {
				id = "vertices",
			},
		},
		chartmeta = {
			preview_time = 2.5,
		},
		scroller = {
			scrollSeconds = function(_, time)
				table.insert(calls, "scroll:" .. time)
			end,
			scrollTimePoint = function(_, point)
				table.insert(calls, "scroll-point:" .. point.id)
			end,
		},
		audio_engine = {
			getStartTime = function()
				return -0.25
			end,
		},
		timer = {
			rate = 0.75,
			getTime = function()
				return 4.5
			end,
			setRate = function(_, rate)
				table.insert(calls, "rate:" .. rate)
			end,
		},
	}
	function model:getPreviewTime()
		return tonumber(self.chartmeta.preview_time)
	end
	model.context = EditorModelContext(model)
	local context = EditorModelContext(model):getViewContext()

	t:eq(context:getSelectionState(), "selection")
	t:eq(context:getSettings(), "settings")
	t:eq(context:getNoteSkin(), "noteSkin")
	t:eq(context:getWave(), "wave")
	t:eq(context:getVisualPointFor({
		id = "vp",
	}), "visualPoint")
	t:eq(context:getLogSpeed(), 12)
	context:setLogSpeed(20)
	t:eq(context:getMaxSnap(), 192)
	t:eq(context:getTools(), model.tools)
	t:eq(context:getAudioSettings(), "audio")
	t:eq(context:getEditorSettings(), "editor")
	local mx, my = context:getMousePosition()
	t:eq(context:getMouseTime(), 1.25)
	context:selectRegion(1, 2, 3, 4)
	context:unselectRegion()
	context:resetVisual()
	t:eq(context:getAnalysisService(), model.analysisService)
	t:eq(context:getAnalysisContext(), model.context:getAnalysisContext())
	t:eq(context:getNcbtContext(), model.ncbtContext)
	t:eq(context:getPoint().absoluteTime, 2.5)
	t:eq(context:getRate(), 0.75)
	t:eq(context:getAudioStartTime(), -0.25)
	t:eq(context:getTimerTime(), 4.5)
	context:setRate(0.5)
	local firstTime, lastTime = context:getTimelineRange()
	t:eq(firstTime, 1)
	t:eq(lastTime, 5)
	t:eq(context:getDensityGraph(), model.graphsGenerator.densityGraph)
	t:eq(context:getVertexDataGraph(), model.graphsGenerator.vertexDatasGraph)
	t:eq(context:getPreviewTime(), 2.5)
	context:scrollSeconds(3)
	context:scrollTimePoint({
		id = "point",
	})

	t:eq(mx, 3)
	t:eq(my, 4)
	t:tdeq(calls, {
		"settings",
		"noteSkin",
		"visual-point:vp",
		"log-speed:20",
		"mouse",
		"select:1:2:3:4",
		"unselect",
		"reset",
		"rate:0.5",
		"timeline",
		"scroll:3",
		"scroll-point:point",
	})
end

---@param t testing.T
function test.note_edit_context_returns_focused_nested_contexts(t)
	local model = {
		layer = {},
		notes = {},
		editorChanges = {},
		visualEngine = {
			selectedNotes = {},
			visual_info = {},
			reset = function() end,
			selectNote = function() end,
		},
		getVisual = function()
			return "visual"
		end,
	}
	local context = EditorModelContext(model):getNoteEditContext()

	t:eq(context:getSelectedNotes(), model.visualEngine.selectedNotes)
	t:eq(context:getVisualInfo(), model.visualEngine.visual_info)
	t:eq(context:getNoteOpsContext():getNotes(), model.notes)
	t:eq(context:getNoteOpsContext():getLayer(), model.layer)
	t:eq(context:getNoteOpsContext():getEditorChanges(), model.editorChanges)
	t:eq(context:getNoteOpsContext():getVisual(), "visual")
	t:eq(context:getEditorNoteContext():getLayer(), model.layer)
	context:selectNote("note")

	model.notes = {
		id = "updated",
	}
	t:eq(context:getNoteOpsContext():getNotes(), model.notes)
end

return test
