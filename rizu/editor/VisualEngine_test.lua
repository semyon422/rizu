local EditorTestFactory = require("rizu.editor.EditorTestFactory")
local VisualEngine = require("rizu.editor.VisualEngine")

local test = {}

---@return rizu.editor.EditorModel
local function createEditorModel()
	local editorModel = EditorTestFactory.createEditorModel()
	local visualEngine = VisualEngine()
	visualEngine.editorModel = editorModel
	editorModel.visualEngine = visualEngine
	editorModel.configModel = {
		configs = {
			settings = {
				editor = {
					speed = 1,
				},
			},
		},
	}
	function editorModel:getIterRange()
		return -math.huge, math.huge
	end
	return editorModel
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.EditorNote
local function addShortNote(editorModel)
	local note = editorModel.noteManager:newNote("tap", 0.25, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())
	editorModel.visualEngine:update()
	return editorModel.visualEngine.notes[1]
end

---@param t testing.T
function test.update_reuses_selected_note_wrapper(t)
	local editorModel = createEditorModel()
	local note = addShortNote(editorModel)

	editorModel.visualEngine:selectNote(note)
	editorModel.visualEngine:update()

	t:eq(#editorModel.visualEngine.notes, 1)
	t:eq(editorModel.visualEngine.notes[1], note)
	t:eq(note.selected, true)
	t:eq(editorModel.visualEngine.selectedNotes[note.startNote], note)
end

---@param t testing.T
function test.rectangle_selection_marks_visible_notes(t)
	local editorModel = createEditorModel()
	local note = addShortNote(editorModel)

	editorModel.visualEngine:selectStart()
	note.selecting = true
	editorModel.visualEngine:update()
	editorModel.visualEngine:selectEnd()

	t:eq(note.selected, true)
	t:eq(editorModel.visualEngine.selectedNotes[note.startNote], note)
	t:eq(editorModel.visualEngine.selection.selecting, false)
end

---@param t testing.T
function test.reset_and_update_remove_stale_selection(t)
	local editorModel = createEditorModel()
	local note = addShortNote(editorModel)

	editorModel.visualEngine:selectNote(note)
	editorModel.notes:removeNote(note.startNote)

	editorModel.visualEngine:reset()
	editorModel.visualEngine:update()

	t:eq(#editorModel.visualEngine.notes, 0)
	t:eq(next(editorModel.visualEngine.selectedNotes), nil)
	t:eq(note.selected, false)
end

return test
