local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes
local selectNote = EditorTestFactory.selectNote

---@param t testing.T
function test.copy_paste(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	selectNote(editorModel, note)

	editorModel.noteManager.clipboard:copy()
	editorModel:setSessionTime(0.75)
	editorModel.noteManager.clipboard:paste()

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
end

---@param t testing.T
function test.cut_undo(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager.clipboard:copy(true)

	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteManager.clipboard.copiedNotes, 1)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)
end

return test
