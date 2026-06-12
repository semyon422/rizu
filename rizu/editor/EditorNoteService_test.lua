local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

---@param t testing.T
function test.constructs_focused_services(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local noteService = editorModel.noteService

	t:ne(noteService.columnService, nil)
	t:ne(noteService.createService, nil)
	t:ne(noteService.commandService, nil)
	t:ne(noteService.clipboardService, nil)
	t:ne(noteService.dragService, nil)
	t:eq(type(noteService.clipboardService.context.getSelectedNotes), "function")
	t:eq(noteService.clipboardService.context.editorChanges, editorModel.editorChanges)
	t:eq(type(noteService.dragService.context.getSelectedNotes), "function")
	t:eq(noteService.dragService.context.editorChanges, editorModel.editorChanges)
	t:eq(type(noteService.createService.context.getSettings), "function")
	t:eq(noteService.createService.context.getEditorNoteContext().getLayer(), editorModel.layer)
	t:eq(type(noteService.columnService.context.getMousePosition), "function")
	t:eq(noteService.columnService.context.getNoteSkin(), editorModel:getNoteSkin())
	t:eq(noteService.grabbedNotes, nil)
	t:eq(noteService.copiedNotes, nil)
end

---@param t testing.T
function test.copy_paste_accesses_clipboard_service_state(t)
	local editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:copyNotes()

	t:eq(#editorModel.noteService:getCopiedNotes(), 1)
	t:eq(editorModel.noteService:getCopiedNotes(), editorModel.noteService.clipboardService.copiedNotes)
end

---@param t testing.T
function test.get_grabbed_notes_accesses_drag_service_state(t)
	local editorModel = EditorTestFactory.createEditorModel()
	editorModel.settings.tool = "ShortNote"
	editorModel.settings.lockSnap = false
	editorModel.mouseTime = 0.25
	editorModel.noteService.columnService.columnOver = 1

	editorModel.noteService:addNote(0.25, "key1")

	t:eq(#editorModel.noteService:getGrabbedNotes(), 1)
	t:eq(editorModel.noteService:getGrabbedNotes(), editorModel.noteService.dragService.grabbedNotes)
end

---@param t testing.T
function test.delete_change_flip_delegate_to_command_service(t)
	local editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	t:eq(editorModel.noteService:deleteNotes(), 1)
	editorModel.editorChanges:undo()
	t:eq(#EditorTestFactory.getNotes(editorModel), 1)

	editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.5, "key1")

	editorModel.noteService:changeType()
	t:eq(#EditorTestFactory.getNotes(editorModel), 2)

	editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.5, "key1")

	editorModel.noteService:flipNotes()
	t:eq(EditorTestFactory.getNotes(editorModel)[1].column, "key4")
end

return test
