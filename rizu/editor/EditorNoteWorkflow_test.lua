local EditorTestFactory = require("rizu.editor.EditorTestFactory")
local Fraction = require("chart.core.Fraction")

local test = {}
local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes
local selectNote = EditorTestFactory.selectNote

---@param t testing.T
function test.add_short_note(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.commandService:addNotes(note:getNotes())

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1].type, "tap")
	t:eq(notes[1].column, "key1")
	t:eq(notes[1]:getTime(), 0.25)
end

---@param t testing.T
function test.add_long_note(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService.commandService:addNotes(note:getNotes())

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
	editorModel.noteService.columnService.columnOver = 1

	editorModel.noteService:addNote(0.25, "key1")

	local notes = getNotes(editorModel)
	t:eq(#notes, 0)
	t:eq(#editorModel.noteService.dragService.grabbedNotes, 1)
	t:eq(editorModel.noteService.dragService.grabbedNotes[1].startNote.column, "key1")

	editorModel.noteService:dropNotes(0.75)
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
	editorModel.noteService.columnService.columnOver = 2

	editorModel.noteService:addNote(0.25, "key2")

	local notes = getNotes(editorModel)
	t:eq(#notes, 0)
	t:eq(#editorModel.noteService.dragService.grabbedNotes, 1)

	editorModel.noteService:dropNotes(0.75)
	notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
end

---@param t testing.T
function test.duplicate_prevention(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.commandService:addNotes(note:getNotes())
	editorModel.noteService.commandService:addNotes(note:getNotes())

	t:eq(#getNotes(editorModel), 1)
end

---@param t testing.T
function test.delete_undo_redo(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	local deleted = editorModel.noteService:deleteNotes()

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
	local note = EditorTestFactory.addSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:copyNotes()
	editorModel:setSessionTime(0.75)
	editorModel.noteService:pasteNotes()

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
	t:eq(notes[2].column, "key1")
end

---@param t testing.T
function test.cut_undo_redo(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:copyNotes(true)
	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteService.clipboardService.copiedNotes, 1)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)

	editorModel.editorChanges:redo()
	t:eq(#getNotes(editorModel), 0)
end

---@param t testing.T
function test.flip_notes(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:flipNotes()

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
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:changeType()

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
	local note = EditorTestFactory.addCommittedNote(editorModel, "hold", 0.25, "key2")
	local originalEndNote = note.endNote
	selectNote(editorModel, note)

	editorModel.noteService:changeType()

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
	editorModel.noteService.columnService.columnOver = 1
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:grabNotes("head", 0.25)
	editorModel.noteService:dropNotes(0.75)

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
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:grabNotes("tail", 0.5)
	editorModel.noteService:dropNotes(0.75)

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
	editorModel.noteService.columnService.columnOver = 1
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:grabNotes("head", 0.25)
	editorModel.noteService.columnService.columnOver = 4
	editorModel.noteService:update()
	editorModel.noteService:dropNotes(0.25)

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
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:grabNotes("head", 0.25)
	editorModel.noteService:dropNotes(0)

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
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:grabNotes("head", 0.25)
	editorModel.noteService:dropNotes(0.5)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.drag_long_body_preserves_duration(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:grabNotes("body", 0.25)
	editorModel.noteService:dropNotes(0.5)

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
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:grabNotes("tail", 0.5)
	editorModel.noteService:dropNotes(0.25)

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.drag_long_body_changes_column(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:grabNotes("body", 0.25)
	editorModel.noteService.columnService.columnOver = 3
	editorModel.noteService:update()
	editorModel.noteService:dropNotes(0.5)

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

---@param t testing.T
function test.drag_selected_long_notes_body_undo_redo(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteService.columnService.columnOver = 2

	local note1 = EditorTestFactory.createNote(editorModel, "hold", 0.25, "key2")
	local note2 = EditorTestFactory.createNote(editorModel, "hold", 0.75, "key3")
	editorModel.noteService.commandService:addNotes(note1:getNotes())
	editorModel.noteService.commandService:addNotes(note2:getNotes())
	editorModel.editorChanges:next()
	editorModel.visualEngine.selectedNotes = {
		[note1.startNote] = note1,
		[note2.startNote] = note2,
	}

	editorModel.noteService:grabNotes("body", 0.25)
	editorModel.noteService.columnService.columnOver = 3
	editorModel.noteService:update()
	editorModel.noteService:dropNotes(0.5)

	local notes = getNotes(editorModel)
	t:eq(#notes, 4)
	t:eq(notes[1]:getTime(), 0.5)
	t:eq(notes[2]:getTime(), 0.75)
	t:eq(notes[3]:getTime(), 1)
	t:eq(notes[4]:getTime(), 1.25)
	t:eq(notes[1].column, "key3")
	t:eq(notes[2].column, "key3")
	t:eq(notes[3].column, "key4")
	t:eq(notes[4].column, "key4")
	t:eq(notes[1].endNote, notes[2])
	t:eq(notes[2].startNote, notes[1])
	t:eq(notes[3].endNote, notes[4])
	t:eq(notes[4].startNote, notes[3])

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 4)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
	t:eq(notes[3]:getTime(), 0.75)
	t:eq(notes[4]:getTime(), 1)
	t:eq(notes[1].column, "key2")
	t:eq(notes[2].column, "key2")
	t:eq(notes[3].column, "key3")
	t:eq(notes[4].column, "key3")

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 4)
	t:eq(notes[1]:getTime(), 0.5)
	t:eq(notes[2]:getTime(), 0.75)
	t:eq(notes[3]:getTime(), 1)
	t:eq(notes[4]:getTime(), 1.25)
	t:eq(notes[1].column, "key3")
	t:eq(notes[3].column, "key4")
end

---@param t testing.T
function test.drag_long_note_keeps_selection_on_cloned_start(t)
	local editorModel = createEditorModel()
	editorModel.settings.lockSnap = false
	editorModel.noteService.columnService.columnOver = 2
	local note = EditorTestFactory.addCommittedNote(editorModel, "hold", 0.25, "key2")
	local originalStartNote = note.startNote
	selectNote(editorModel, note)

	editorModel.noteService:grabNotes("body", 0.25)
	editorModel.noteService:dropNotes(0.5)

	t:eq(editorModel.visualEngine.selectedNotes[originalStartNote], nil)
	t:eq(editorModel.visualEngine.selectedNotes[note.startNote], note)
	t:ne(note.startNote, originalStartNote)
end

---@param t testing.T
function test.delete_undo_clears_selection_state(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:deleteNotes()
	t:eq(editorModel.visualEngine.selectedNotes[note.startNote], nil)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)
	t:eq(next(editorModel.visualEngine.selectedNotes), nil)
	t:eq(editorModel.visualEngine.reset_count, 1)
end

---@param t testing.T
function test.cut_clears_stale_selection_and_undo_restores_notes(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addCommittedSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:copyNotes(true)

	t:eq(#getNotes(editorModel), 0)
	t:eq(editorModel.visualEngine.selectedNotes[note.startNote], nil)

	editorModel.editorChanges:undo()
	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
	t:eq(next(editorModel.visualEngine.selectedNotes), nil)
end

---@param t testing.T
function test.paste_does_not_select_pasted_notes(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addSelectedNote(editorModel, "hold", 0.25, "key2")

	editorModel.noteService:copyNotes()
	editorModel:setSessionTime(0.75)
	editorModel.noteService:pasteNotes()

	t:eq(#getNotes(editorModel), 4)
	t:eq(next(editorModel.visualEngine.selectedNotes), note.startNote)
	t:eq(editorModel.visualEngine.selectedNotes[note.startNote], note)
end

return test
