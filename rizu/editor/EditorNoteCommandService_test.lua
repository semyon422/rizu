local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes

---@param t testing.T
function test.delete_remove_and_undo(t)
	local editorModel = createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	local deleted = editorModel.noteService.commandService:deleteSelected()

	t:eq(deleted, 1)
	t:eq(#getNotes(editorModel), 0)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)
end

---@param t testing.T
function test.change_type_and_flip_selected(t)
	local editorModel = createEditorModel()
	local note = EditorTestFactory.addSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.commandService:changeSelectedType()

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1].type, "hold")
	t:eq(notes[2].type, "hold")

	EditorTestFactory.selectNote(editorModel, note)
	editorModel.noteService.commandService:flipSelected()

	notes = getNotes(editorModel)
	t:eq(notes[1].column, "key4")
	t:eq(notes[2].column, "key4")
end

---@param t testing.T
function test.mixed_ops_transaction_undo_redo(t)
	local editorModel = createEditorModel()
	local noteToRemove = EditorTestFactory.createNote(editorModel, "tap", 0.25, "key1")
	local noteToAdd = EditorTestFactory.createNote(editorModel, "tap", 0.75, "key2")
	local noteOps = editorModel.noteService.commandService:getNoteOps()
	t:eq(noteOps.context:getNotes(), editorModel.notes)
	t:eq(noteOps.context:getEditorChanges(), editorModel.editorChanges)

	noteOps:addNotes(noteToRemove:getNotes())
	editorModel.editorChanges:next()

	editorModel.editorChanges:reset()
	noteOps:removeNotes(noteToRemove:getNotes())
	noteOps:addNotes(noteToAdd:getNotes())
	editorModel.editorChanges:next()

	local notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(notes[1].column, "key2")

	editorModel.editorChanges:undo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[1].column, "key1")

	editorModel.editorChanges:redo()
	notes = getNotes(editorModel)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(notes[1].column, "key2")
end

return test
