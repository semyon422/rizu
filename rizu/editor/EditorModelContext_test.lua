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
	local model = {
		max_snap = 192,
		configModel = {
			configs = {
				settings = {
					editor = "editor",
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
		getMousePosition = function()
			table.insert(calls, "mouse")
			return 3, 4
		end,
		getMouseTime = function()
			return 1.25
		end,
		selectRegion = function(x1, y1, x2, y2)
			table.insert(calls, ("select:%s:%s:%s:%s"):format(x1, y1, x2, y2))
		end,
		unselectRegion = function()
			table.insert(calls, "unselect")
		end,
	}
	local context = EditorModelContext(model):getViewContext()

	t:eq(context:getSelectionState(), "selection")
	t:eq(context:getSettings(), "settings")
	t:eq(context:getNoteSkin(), "noteSkin")
	t:eq(context:getMaxSnap(), 192)
	t:eq(context:getEditorSettings(), "editor")
	local mx, my = context:getMousePosition()
	t:eq(context:getMouseTime(), 1.25)
	context:selectRegion(1, 2, 3, 4)
	context:unselectRegion()
	context:resetVisual()

	t:eq(mx, 3)
	t:eq(my, 4)
	t:tdeq(calls, {
		"settings",
		"noteSkin",
		"mouse",
		"select:1:2:3:4",
		"unselect",
		"reset",
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
