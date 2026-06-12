local EditorTestFactory = require("rizu.editor.EditorTestFactory")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes

---@param t testing.T
function test.copy_paste(t)
	local editorModel = createEditorModel()
	EditorTestFactory.addSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.clipboardService:copy()
	editorModel:setSessionTime(0.75)
	editorModel.noteService.clipboardService:paste()

	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.75)
end

---@param t testing.T
function test.cut_undo(t)
	local editorModel = createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService.clipboardService:copy(true)

	t:eq(#getNotes(editorModel), 0)
	t:eq(#editorModel.noteService.clipboardService.copiedNotes, 1)

	editorModel.editorChanges:undo()
	t:eq(#getNotes(editorModel), 1)
end

return test
