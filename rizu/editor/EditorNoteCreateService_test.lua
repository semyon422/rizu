local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes

---@param t testing.T
function test.new_note(t)
	local editorModel = createEditorModel()

	local note = editorModel.noteService.createService:newNote("tap", 0.25, "key1")

	t:eq(note.startNote.column, "key1")
	t:eq(note.startNote.type, "tap")
	t:eq(note.startNote:getTime(), 0.25)
end

---@param t testing.T
function test.add_note_commits_on_drop(t)
	local editorModel = createEditorModel()
	editorModel.settings.tool = "ShortNote"
	editorModel.settings.lockSnap = false
	editorModel.mouseTime = 0.25
	editorModel.noteService.columnService.columnOver = 1

	editorModel.noteService.createService:addNote(0.25, "key1")

	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteService.dragService.grabbedNotes, 1)

	editorModel.noteService:dropNotes(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
end

return test
