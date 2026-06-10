local EditorTestFactory = require("rizu.editor.EditorTestFactory")
local NoteChartLoader = require("rizu.editor.NoteChartLoader")
local Converter = require("chart.chartedit.Converter")

local test = {}

---@param editorModel rizu.editor.EditorModel
local function reloadThroughNoteChartLoader(editorModel)
	local chart = Converter:save({main = editorModel.layer}, editorModel.notes)
	local loadedEditorModel = EditorTestFactory.createEditorModel()
	loadedEditorModel.chart = chart

	local loader = NoteChartLoader()
	loader.editorModel = loadedEditorModel
	loadedEditorModel.noteChartLoader = loader
	loadedEditorModel.layer, loadedEditorModel.notes = loader:load()
	loadedEditorModel.visual = loadedEditorModel.layer.visuals.main
	return loadedEditorModel
end

---@param t testing.T
function test.interval_shrink_undo_save_after_load(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local vertex = editorModel.layer.points:getFirstPoint()._vertex

	editorModel.intervalManager:update(vertex, 3)
	editorModel.editorChanges:reset()

	local note = editorModel.noteManager:newNote("tap", 0.75, "key1")
	---@cast note -?
	editorModel.noteManager:_addNotes(note:getNotes())

	local loadedEditorModel = reloadThroughNoteChartLoader(editorModel)
	local loadedVertex = loadedEditorModel.layer.points:getFirstPoint()._vertex
	local loadedLoader = loadedEditorModel.noteChartLoader

	loadedEditorModel.intervalManager:update(loadedVertex, 1)
	t:eq(#loadedEditorModel.notes:getNotes(), 0)

	loadedEditorModel.editorChanges:undo()
	t:eq(#loadedEditorModel.notes:getNotes(), 1)

	loadedLoader:save()
	t:eq(#loadedEditorModel.chart.notes:getNotes(), 1)
end

return test
