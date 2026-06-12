local EditorOverlayActionService = require("rizu.editor.EditorOverlayActionService")
local EditorViewState = require("rizu.editor.EditorViewState")

local test = {}

---@param t testing.T
function test.ui_action_methods_update_editor_state(t)
	local calls = {}
	local point = {}
	local selectedVisualPoint = {}
	local selectedNote = {
		startNote = {
			visualPoint = selectedVisualPoint,
		},
	}
	local editorModel = {
		chartmeta = {},
		getSessionTime = function()
			return 12.5
		end,
		viewState = EditorViewState(),
		noteService = {
			changeType = function()
				table.insert(calls, "change-type")
			end,
		},
		scrollPoint = function(_, scrolledPoint)
			table.insert(calls, "scroll")
			t:eq(scrolledPoint, point)
		end,
		visualEngine = {
			selectedNotes = {
				[selectedNote.startNote] = selectedNote,
			},
		},
	}
	selectedVisualPoint.point = point

	local service = EditorOverlayActionService()
	service:setPreviewTimeToSession(editorModel)
	service:setOverlayState(editorModel, "notes")
	service:changeSelectedNoteType(editorModel)
	local scrolled = service:scrollToFirstSelectedNote(editorModel)
	service:setVisualPointComment(selectedVisualPoint, "")
	service:setVisualPointComment(selectedVisualPoint, "comment")
	service:resetVisualPointComment(selectedVisualPoint)
	service:setSelectedNotesComment(editorModel, "batch")
	service:resetSelectedNotesComment(editorModel)

	t:eq(editorModel.chartmeta.preview_time, 12.5)
	t:eq(service:getOverlayState(editorModel), "notes")
	t:eq(scrolled, true)
	t:eq(selectedVisualPoint.comment, nil)
	t:eq(selectedVisualPoint.temp_comment, nil)
	t:tdeq(calls, {"change-type", "scroll"})
end

---@param t testing.T
function test.scroll_to_first_selected_note_returns_false_without_selection(t)
	local editorModel = {
		visualEngine = {
			selectedNotes = {},
		},
		scrollPoint = function()
			error("unexpected scroll")
		end,
	}

	t:eq(EditorOverlayActionService():scrollToFirstSelectedNote(editorModel), false)
end

---@param t testing.T
function test.bms_ui_methods_apply_offset_tempo(t)
	local calls = {}
	local layer = {}
	local editorModel = {
		layer = layer,
		bmsToolsContext = {
			offset = 0.25,
			resetOffsetTempo = function(_, appliedLayer)
				table.insert(calls, "reset")
				t:eq(appliedLayer, layer)
			end,
		},
	}

	local service = EditorOverlayActionService()
	service:applyBmsOffsetTempo(editorModel)
	service:changeBmsOffset(editorModel, 0.001)

	t:eq(editorModel.bmsToolsContext.offset, 0.251)
	t:tdeq(calls, {"reset", "reset"})
end

return test
