local EditorPlayfieldService = require("rizu.editor.view.playfield.EditorPlayfieldService")

local test = {}

local function createContext(fields)
	return {
		getViewState = function()
			return fields.viewState
		end,
		getSelectionState = function()
			return fields.selectionState
		end,
		getEditorSettings = function()
			return fields.editor
		end,
		getNoteService = function()
			return fields.noteService
		end,
		getVisualEngine = function()
			return fields.visualEngine
		end,
		selectNote = function(_, note)
			table.insert(fields.calls, "select-note")
			fields.selectedNote = note
		end,
		selectStart = function()
			table.insert(fields.calls, "select-start")
		end,
		selectEnd = function()
			table.insert(fields.calls, "select-end")
		end,
	}
end

---@param t testing.T
function test.state_helpers_read_focused_contexts(t)
	local rect = {1, 2, 3, 4}
	local service = EditorPlayfieldService()
	local context = createContext({
		calls = {},
		editor = {
			tool = "ShortNote",
		},
		viewState = {
			getOverlayState = function()
				return "notes"
			end,
		},
		selectionState = {
			getRect = function()
				return rect
			end,
		},
	})

	t:eq(service:isNotesActive(context), true)
	t:eq(service:getSelectionRect(context), rect)
	t:eq(service:canAddNote(context), true)
	t:eq(service:isSelectTool(context), false)
end

---@param t testing.T
function test.tool_helpers_distinguish_select_and_note_tools(t)
	local service = EditorPlayfieldService()
	local context = createContext({
		calls = {},
		editor = {
			tool = "Select",
		},
		viewState = {
			getOverlayState = function()
				return "notes"
			end,
		},
		selectionState = {},
	})

	t:eq(service:canAddNote(context), false)
	t:eq(service:isSelectTool(context), true)

	context:getEditorSettings().tool = "SoundNote"

	t:eq(service:canAddNote(context), false)
	t:eq(service:isSelectTool(context), false)
end

---@param t testing.T
function test.note_editing_is_active_only_on_notes_tab(t)
	local service = EditorPlayfieldService()
	local activeTab = "notes"
	local context = createContext({
		calls = {},
		editor = {
			tool = "ShortNote",
		},
		viewState = {
			getOverlayState = function()
				return activeTab
			end,
		},
		selectionState = {},
	})

	t:eq(service:isNotesActive(context), true)
	t:eq(service:canAddNote(context), true)

	activeTab = "timings"
	t:eq(service:isNotesActive(context), false)
	t:eq(service:canAddNote(context), false)

	context:getEditorSettings().tool = "Select"
	t:eq(service:isSelectTool(context), false)

	activeTab = "notes"
	t:eq(service:isSelectTool(context), true)
end

---@param t testing.T
function test.note_commands_delegate_to_note_service_and_visual_engine(t)
	local calls = {}
	local note = {}
	local service = EditorPlayfieldService()
	local fields = {
		calls = calls,
		editor = {},
		viewState = {},
		selectionState = {},
		visualEngine = {},
		noteService = {
			addNote = function(_, time, column)
				table.insert(calls, ("add:%s:%s"):format(time, column))
			end,
			grabNotes = function(_, part, mouseTime)
				table.insert(calls, ("grab:%s:%s"):format(part, mouseTime))
			end,
			removeNote = function(_, removedNote)
				table.insert(calls, "remove")
				t:eq(removedNote, note)
			end,
		},
	}
	local context = createContext(fields)

	service:addNote(context, 1.5, 3)
	service:selectNoteAndGrab(context, note, "tail", 2.5)
	service:removeNote(context, note)

	t:eq(fields.selectedNote, note)
	t:tdeq(calls, {
		"add:1.5:key3",
		"select-note",
		"grab:tail:2.5",
		"remove",
	})
end

---@param t testing.T
function test.release_commands_drop_grabbed_notes_and_end_selection(t)
	local calls = {}
	local service = EditorPlayfieldService()
	local grabbedNote = {}
	local rect = {1, 2, 3, 4}
	local context = createContext({
		calls = calls,
		editor = {},
		viewState = {},
		selectionState = {
			getRect = function()
				return rect
			end,
		},
		noteService = {
			getGrabbedNotes = function()
				return {grabbedNote}
			end,
			dropNotes = function(_, mouseTime)
				table.insert(calls, "drop:" .. mouseTime)
			end,
		},
	})

	t:eq(service:dropGrabbedNotes(context, 3.5), true)
	t:eq(service:selectEndIfSelecting(context), true)

	context.getSelectionState = function()
		return {
			getRect = function()
				return nil
			end,
		}
	end
	context.getNoteService = function()
		return {
			getGrabbedNotes = function()
				return {}
			end,
		}
	end

	t:eq(service:dropGrabbedNotes(context, 4.5), false)
	t:eq(service:selectEndIfSelecting(context), false)
	t:tdeq(calls, {"drop:3.5", "select-end"})
end

return test
