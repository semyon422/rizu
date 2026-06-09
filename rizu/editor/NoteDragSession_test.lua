local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes
local selectNote = EditorTestFactory.selectNote

---@param t testing.T
function test.grab_drop(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 1
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager.dragSession:grab("head", 0.25)
	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteManager.grabbedNotes, 1)

	editorModel.noteManager.dragSession:drop(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(#editorModel.noteManager.grabbedNotes, 0)
end

---@param t testing.T
function test.grab_new(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 1
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?

	editorModel.noteManager.dragSession:grabNew(note, "head", 0.25)
	editorModel.noteManager.dragSession:drop(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
end

return test
