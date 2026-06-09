local EditorTestFactory = require("rizu.editor.EditorTestFactory")
local Fraction = require("chart.core.Fraction")

local test = {}
local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes
local selectNote = EditorTestFactory.selectNote

---@param t testing.T
function test.add_short_note(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?

	editorModel.noteManager:_addNotes(note:getNotes())

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].type, "tap")
	t:eq(notes[1].column, "key1")
	t:eq(notes[1]:getTime(), 0.25)
end

---@param t testing.T
function test.add_long_note(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?

	editorModel.noteManager:_addNotes(note:getNotes())

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1].weight, 1)
	t:eq(notes[2].weight, -1)
	t:eq(notes[1].column, "key2")
	t:eq(notes[2].column, "key2")
	t:eq(notes[2].visualPoint.point.time, Fraction(1, 2))
end

---@param t testing.T
function test.add_note_starts_drag(t)
	local editorModel = createEditorModel()
	editorModel.settings.tool = "ShortNote"
	editorModel.settings.lockSnap = false
	editorModel.mouseTime = 0.25
	editorModel.noteManager.columnOver = 1

	editorModel.noteManager:addNote(0.25, "key1")

	local notes = getNotes(editorModel)
	t:eq(#notes, 0)
	t:eq(#editorModel.noteManager.grabbedNotes, 1)
	t:eq(editorModel.noteManager.grabbedNotes[1].startNote.column, "key1")

	editorModel.noteManager:dropNotes(0.75)
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 0)
end

---@param t testing.T
function test.add_long_note_starts_tail_drag(t)
	local editorModel = createEditorModel()
	editorModel.settings.tool = "LongNote"
	editorModel.settings.lockSnap = false
	editorModel.mouseTime = 0.25
	editorModel.noteManager.columnOver = 2

	editorModel.noteManager:addNote(0.25, "key2")

	local notes = getNotes(editorModel)
	t:eq(#notes, 0)
	t:eq(#editorModel.noteManager.grabbedNotes, 1)

	editorModel.noteManager:dropNotes(0.75)
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
end

---@param t testing.T
function test.duplicate_prevention(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?

	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.noteManager:_addNotes(note:getNotes())

	t:eq(#getNotes(editorModel), 1)
end

---@param t testing.T
function test.delete_undo_redo(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	local deleted = editorModel.noteManager:deleteNotes()

	t:eq(deleted, 1)
	t:eq(#getNotes(editorModel), 0)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)

	editorModel.editorChanges:redo()
	t:eq(#getNotes(editorModel), 0)
end

---@param t testing.T
function test.copy_paste(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	selectNote(editorModel, note)

	editorModel.noteManager:copyNotes()
	editorModel:setSessionTime(0.75)
	editorModel.noteManager:pasteNotes()

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
	t:eq(notes[2].column, "key1")
end

---@param t testing.T
function test.cut_undo_redo(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:copyNotes(true)
	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteManager.copiedNotes, 1)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)

	editorModel.editorChanges:redo()
	t:eq(#getNotes(editorModel), 0)
end

---@param t testing.T
function test.flip_notes(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:flipNotes()

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].column, "key4")

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].column, "key1")

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].column, "key4")
end

---@param t testing.T
function test.change_short_to_long_undo_redo(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:changeType()

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(note.endNote, notes[2])
	t:eq(notes[1].type, "hold")
	t:eq(notes[1].weight, 1)
	t:eq(notes[2].type, "hold")
	t:eq(notes[2].weight, -1)

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(note.endNote, nil)
	t:eq(notes[1].type, "tap")
	t:eq(notes[1].weight, 0)

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(note.endNote, notes[2])
	t:eq(notes[1].type, "hold")
	t:eq(notes[2].type, "hold")
end

---@param t testing.T
function test.change_long_to_short_undo_redo(t)
	local editorModel = createEditorModel()
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	local originalEndNote = note.endNote
	selectNote(editorModel, note)

	editorModel.noteManager:changeType()

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(note.endNote, nil)
	t:eq(notes[1].type, "tap")
	t:eq(notes[1].weight, 0)
	t:eq(originalEndNote.type, "ignore")

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(note.endNote, originalEndNote)
	t:eq(notes[1].type, "hold")
	t:eq(notes[1].weight, 1)
	t:eq(notes[2].type, "hold")
	t:eq(notes[2].weight, -1)

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(note.endNote, nil)
	t:eq(notes[1].type, "tap")
end

---@param t testing.T
function test.drag_short_note_undo_redo(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 1
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("head", 0.25)
	editorModel.noteManager:dropNotes(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(notes[1].column, "key1")

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.25)

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
end

---@param t testing.T
function test.drag_long_tail_undo_redo(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 2
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("tail", 0.5)
	editorModel.noteManager:dropNotes(0.75)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
	t:eq(notes[1].column, "key2")
	t:eq(notes[2].column, "key2")

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
end

---@param t testing.T
function test.lock_snap_drag_column_undo_redo(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = true
	editorModel.noteManager.columnOver = 1
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("head", 0.25)
	editorModel.noteManager.columnOver = 4
	editorModel.noteManager:update()
	editorModel.noteManager:dropNotes(0.25)

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].column, "key4")
	t:eq(notes[1]:getTime(), 0.25)

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].column, "key1")
	t:eq(notes[1]:getTime(), 0.25)

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].column, "key4")
	t:eq(notes[1]:getTime(), 0.25)
end

---@param t testing.T
function test.drag_long_head_undo_redo(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 2
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("head", 0.25)
	editorModel.noteManager:dropNotes(0)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0)
	t:eq(notes[2]:getTime(), 0.5)

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.drag_long_head_to_tail_keeps_length(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 2
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("head", 0.25)
	editorModel.noteManager:dropNotes(0.5)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.drag_long_body_preserves_duration(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 2
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("body", 0.25)
	editorModel.noteManager:dropNotes(0.5)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.5)
	t:eq(notes[2]:getTime(), 0.75)
	t:eq(notes[2]:getTime() - notes[1]:getTime(), 0.25)

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.drag_long_tail_to_head_keeps_length(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 2
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("tail", 0.5)
	editorModel.noteManager:dropNotes(0.25)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.drag_long_body_changes_column(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteManager.columnOver = 2
	local note = editorModel.noteManager:newNote("hold", 0.25, "key2")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.editorChanges:next()
	selectNote(editorModel, note)

	editorModel.noteManager:grabNotes("body", 0.25)
	editorModel.noteManager.columnOver = 3
	editorModel.noteManager:update()
	editorModel.noteManager:dropNotes(0.5)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1].column, "key3")
	t:eq(notes[2].column, "key3")
	t:eq(notes[1]:getTime(), 0.5)
	t:eq(notes[2]:getTime(), 0.75)

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1].column, "key2")
	t:eq(notes[2].column, "key2")
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

return test
