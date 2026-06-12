local EditorModelContext = require("rizu.editor.EditorModelContext")

local test = {}

---@param t testing.T
function test.methods_read_current_model_state(t)
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
		max_snap = 192,
		getSelectionState = function()
			return "selection"
		end,
	}
	local context = EditorModelContext(model)

	t:eq(context:getLayer().id, "layer-1")
	t:eq(context:getChart().id, "chart-1")
	t:eq(context:getEditorChanges(), model.editorChanges)
	t:eq(context:getMaxSnap(), 192)
	t:eq(context:getSelectionState(), "selection")

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
function test.methods_delegate_to_model(t)
	local calls = {}
	local model = {
		getSettings = function()
			table.insert(calls, "settings")
			return "settings"
		end,
		getNoteSkin = function()
			table.insert(calls, "noteSkin")
			return "noteSkin"
		end,
		setLoaded = function(_, loaded)
			table.insert(calls, "loaded:" .. tostring(loaded))
		end,
		setResourcesLoaded = function(_, loaded)
			table.insert(calls, "resources:" .. tostring(loaded))
		end,
		setWave = function(_, wave)
			table.insert(calls, "wave:" .. wave)
		end,
		getPoint = function()
			table.insert(calls, "point")
			return "point"
		end,
		getMousePosition = function()
			table.insert(calls, "mouse")
			return 3, 4
		end,
		selectRegion = function(x1, y1, x2, y2)
			table.insert(calls, ("select:%s:%s:%s:%s"):format(x1, y1, x2, y2))
		end,
		unselectRegion = function()
			table.insert(calls, "unselect")
		end,
	}
	local context = EditorModelContext(model)

	t:eq(context:getSettings(), "settings")
	t:eq(context:getNoteSkin(), "noteSkin")
	context:setLoaded(true)
	context:setResourcesLoaded(false)
	context:setWave("wave")
	t:eq(context:getPoint(), "point")
	local mx, my = context:getMousePosition()
	context:selectRegion(1, 2, 3, 4)
	context:unselectRegion()

	t:eq(mx, 3)
	t:eq(my, 4)
	t:tdeq(calls, {
		"settings",
		"noteSkin",
		"loaded:true",
		"resources:false",
		"wave:wave",
		"point",
		"mouse",
		"select:1:2:3:4",
		"unselect",
	})
end

---@param t testing.T
function test.note_service_methods_use_current_model_state(t)
	local model = {
		notes = {
			id = "notes",
		},
		editorChanges = {
			id = "changes",
		},
		visualEngine = {
			selectedNotes = {
				id = "selected",
			},
			visual_info = {
				id = "visualInfo",
			},
			reset = function() end,
			selectNote = function() end,
		},
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
	}
	local context = EditorModelContext(model)

	t:eq(context:getNoteSkin(), "noteSkin")
	t:eq(context:getSelectedNotes(), model.visualEngine.selectedNotes)
	t:eq(context:getNoteOpsContext():getNotes(), model.notes)
	t:eq(context:getMouseTime(), 1.25)
	t:eq(context:getPoint(), "point")
	t:eq(context:getVisualInfo(), model.visualEngine.visual_info)
	t:eq(context:getEditorNoteContext(), context)

	model.notes = {
		id = "updated",
	}
	t:eq(context:getNoteOpsContext():getNotes(), model.notes)
end

return test
