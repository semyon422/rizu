local EditorSelectionService = require("rizu.editor.EditorSelectionService")
local EditorSelectionState = require("rizu.editor.EditorSelectionState")

local test = {}

---@param t testing.T
function test.select_note_uses_multi_select_predicate(t)
	local note = {}
	local selectedNote
	local keepOthers
	local editorModel = {
		isMultiSelectRequested = function()
			return true
		end,
		visualEngine = {
			selectNote = function(_, nextNote, nextKeepOthers)
				selectedNote = nextNote
				keepOthers = nextKeepOthers
			end,
		},
	}

	EditorSelectionService():selectNote(editorModel, note)

	t:eq(selectedNote, note)
	t:eq(keepOthers, true)
end

---@param t testing.T
function test.rectangle_selection_lifecycle(t)
	local calls = {}
	local selectionState = EditorSelectionState()
	local editorModel = {
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
		getMouseTime = function()
			return 1
		end,
		getSelectionState = function()
			return selectionState
		end,
		selectRegion = function(x1, y1, x2, y2)
			table.insert(calls, ("select:%s:%s:%s:%s"):format(x1, y1, x2, y2))
		end,
		unselectRegion = function()
			table.insert(calls, "unselect")
		end,
	}

	local service = EditorSelectionService()
	service:selectStart(editorModel)
	service:updateSelectionRect(editorModel, {speed = 2}, {
		getTimePosition = function(_, time)
			return time * 10
		end,
	}, 6)
	service:selectEnd(editorModel)

	t:tdeq(calls, {
		"visual-start",
		"select:3:4:3:4",
		"select:3:100:3:4",
		"visual-end",
		"unselect",
	})
end

return test
