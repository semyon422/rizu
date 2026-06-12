local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel

---@param t testing.T
function test.create(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	t:eq(note.startNote.type, "hold")
	t:eq(note.endNote.type, "hold")
	t:eq(note.startNote.weight, 1)
	t:eq(note.endNote.weight, -1)
	t:eq(note.startNote.column, "key2")
	t:eq(note.endNote.column, "key2")
	t:eq(note.startNote:getTime(), 0.25)
	t:eq(note.endNote:getTime(), 0.5)
	t:eq(note.startNote.endNote, note.endNote)
	t:eq(note.endNote.startNote, note.startNote)
end

---@param t testing.T
function test.copy_paste(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")
	local copyPoint = note.startNote.visualPoint.point
	local pastePoint = editorModel:getDtpAbsolute(0.75)

	note:copy(copyPoint)
	local notes = note:paste(pastePoint)

	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(notes[2]:getTime(), 1)
	t:eq(notes[1].column, "key2")
	t:eq(notes[2].column, "key2")
	t:eq(notes[1].endNote, notes[2])
	t:eq(notes[2].startNote, notes[1])
	t:ne(notes[1].endNote, note.endNote)
	t:ne(notes[2].startNote, note.startNote)
end

---@param t testing.T
function test.copy_paste_preserves_duration_after_timing_change(t)
	local editorModel = createEditorModel()
	local vertex = editorModel.layer.points:getFirstPoint()._vertex
	editorModel.intervalManager:update(vertex, 3)

	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")
	local copyPoint = note.startNote.visualPoint.point
	local pastePoint = editorModel:getDtpAbsolute(0.5)
	local duration = note.endNote:getTime() - note.startNote:getTime()

	note:copy(copyPoint)
	local notes = note:paste(pastePoint)

	t:eq(notes[1]:getTime(), 0.5)
	t:aeq(notes[2]:getTime() - notes[1]:getTime(), duration, 1e-9)
end

---@param t testing.T
function test.grab_head_drop(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")
	local originalStartNote = note.startNote
	local originalEndNote = note.endNote

	note:grab(0.25, "head", 0, false)
	t:ne(note.startNote, originalStartNote)
	note:drop(0)

	t:eq(note.startNote:getTime(), 0)
	t:eq(note.endNote:getTime(), 0.5)
	t:eq(originalStartNote:getTime(), 0.25)
	t:eq(originalEndNote:getTime(), 0.5)
end

---@param t testing.T
function test.grab_tail_drop(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	note:grab(0.5, "tail", 0, false)
	note:drop(0.75)

	t:eq(note.startNote:getTime(), 0.25)
	t:eq(note.endNote:getTime(), 0.75)
end

---@param t testing.T
function test.grab_body_drop_preserves_duration(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	note:grab(0.25, "body", 0, false)
	note:drop(0.5)

	t:eq(note.startNote:getTime(), 0.5)
	t:eq(note.endNote:getTime(), 0.75)
end

---@param t testing.T
function test.grab_body_from_middle_preserves_cursor_offset(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	note:grab(0.375, "body", 0, false)
	note:drop(0.625)

	t:eq(note.startNote:getTime(), 0.5)
	t:eq(note.endNote:getTime(), 0.75)
end

---@param t testing.T
function test.head_to_tail_keeps_length(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	note:grab(0.25, "head", 0, false)
	note:drop(0.5)

	t:eq(note.startNote:getTime(), 0.25)
	t:eq(note.endNote:getTime(), 0.5)
end

---@param t testing.T
function test.tail_to_head_keeps_length(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	note:grab(0.5, "tail", 0, false)
	note:drop(0.25)

	t:eq(note.startNote:getTime(), 0.25)
	t:eq(note.endNote:getTime(), 0.5)
end

---@param t testing.T
function test.lock_snap_grab_clones(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")
	local originalStartNote = note.startNote
	local originalEndNote = note.endNote

	note:grab(0.25, "body", 0, true)
	note:setColumn("key3")

	t:ne(note.startNote, originalStartNote)
	t:ne(note.endNote, originalEndNote)
	t:eq(note.startNote.column, "key3")
	t:eq(note.endNote.column, "key3")
	t:eq(originalStartNote.column, "key2")
	t:eq(originalEndNote.column, "key2")
end

return test
