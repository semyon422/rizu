local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes

---@param t testing.T
function test.grab_drop(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteService.columnService.columnOver = 1
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.dragService:grab("head", 0.25)
	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteService.dragService.grabbedNotes, 1)

	editorModel.noteService.dragService:drop(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(#editorModel.noteService.dragService.grabbedNotes, 0)
end

---@param t testing.T
function test.grab_new(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteService.columnService.columnOver = 1
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.dragService:grabNew(note, "head", 0.25)
	editorModel.noteService.dragService:drop(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
end

return test
