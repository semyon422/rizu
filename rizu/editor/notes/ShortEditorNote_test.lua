local EditorTestFactory = require("rizu.editor.test.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel

---@param t testing.T
function test.create(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")

	t:eq(note.startNote.type, "tap")
	t:eq(note.startNote.column, "key1")
	t:eq(note.startNote:getTime(), 0.25)
	t:eq(note.endNote, nil)
	t:eq(#note:getNotes(), 1)
end

---@param t testing.T
function test.copy_paste(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")
	local copyPoint = note.startNote.visualPoint.point
	local pastePoint = editorModel:getDtpAbsolute(0.75)

	note:copy(copyPoint)
	local notes = note:paste(pastePoint)

	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(notes[1].column, "key1")
end

---@param t testing.T
function test.grab_drop(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")
	local originalStartNote = note.startNote

	note:grab(0.25, "head", 0, false)
	t:ne(note.startNote, originalStartNote)
	note:drop(0.75)

	t:eq(note.startNote:getTime(), 0.75)
	t:eq(originalStartNote:getTime(), 0.25)
end

---@param t testing.T
function test.lock_snap_grab_clones(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")
	local originalStartNote = note.startNote

	note:grab(0.25, "head", 0, true)
	note:setColumn("key2")

	t:ne(note.startNote, originalStartNote)
	t:eq(note.startNote.column, "key2")
	t:eq(originalStartNote.column, "key1")
	t:eq(note.startNote:getTime(), 0.25)
end

return test
