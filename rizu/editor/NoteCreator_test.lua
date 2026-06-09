local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes

---@param t testing.T
function test.new_note(t)
	local editorModel = createEditorModel()

	local note = editorModel.noteManager.creator:newNote("tap", 0.25, "key1")
	---@cast note -?

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
	editorModel.noteManager.columnOver = 1

	editorModel.noteManager.creator:addNote(0.25, "key1")

	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteManager.grabbedNotes, 1)

	editorModel.noteManager:dropNotes(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
end

return test
