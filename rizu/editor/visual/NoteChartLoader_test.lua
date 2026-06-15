local EditorTestFactory = require("rizu.editor.test.EditorTestFactory")
local NoteChartLoader = require("rizu.editor.visual.NoteChartLoader")
local Converter = require("chart.chartedit.Converter")
local Fraction = require("chart.core.Fraction")

local test = {}

local selectNote = EditorTestFactory.selectNote

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.NoteChartLoader
local function attachLoader(editorModel)
	editorModel.chart = Converter:save({main = editorModel.layer}, editorModel.notes)
	local loader = NoteChartLoader()
	loader:setContext(EditorTestFactory.createNoteChartLoaderContext(editorModel))
	editorModel.noteChartLoader = loader
	return loader
end

---@param editorModel rizu.editor.EditorModel
local function reloadThroughNoteChartLoader(editorModel)
	local chart = Converter:save({main = editorModel.layer}, editorModel.notes)
	local loadedEditorModel = EditorTestFactory.createEditorModel()
	loadedEditorModel.chart = chart

	local loader = NoteChartLoader()
	loader:setContext(EditorTestFactory.createNoteChartLoaderContext(loadedEditorModel))
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

	local note = EditorTestFactory.addNote(editorModel, "tap", 0.75, "key1")

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

---@param t testing.T
function test.long_note_save_load_roundtrip(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local note = EditorTestFactory.addNote(editorModel, "hold", 0.25, "key2")

	local loadedEditorModel = reloadThroughNoteChartLoader(editorModel)
	local notes = loadedEditorModel.notes:getNotes()

	t:eq(#notes, 2)
	t:eq(notes[1].type, "hold")
	t:eq(notes[2].type, "hold")
	t:eq(notes[1].weight, 1)
	t:eq(notes[2].weight, -1)
	t:eq(notes[1].column, "key2")
	t:eq(notes[2].column, "key2")
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[2]:getTime(), 0.5)
end

---@param t testing.T
function test.timing_edit_save_load_roundtrip(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local intervalManager = editorModel.intervalManager
	local point = editorModel:getDtpAbsolute(0.5)
	local vertex = intervalManager:split(point)
	intervalManager:update(vertex, 2)

	local loadedEditorModel = reloadThroughNoteChartLoader(editorModel)
	local firstPoint = loadedEditorModel.layer.points:getFirstPoint()
	local secondPoint = firstPoint.next
	---@cast secondPoint -?

	t:eq(firstPoint._vertex.offset, 0)
	t:eq(secondPoint._vertex.offset, 0.5)
	t:eq(secondPoint.time, Fraction(1, 2))
	t:eq(secondPoint._vertex.beats, 2)

	local reloadedEditorModel = reloadThroughNoteChartLoader(loadedEditorModel)
	local reloadedSecondPoint = reloadedEditorModel.layer.points:getFirstPoint().next
	---@cast reloadedSecondPoint -?
	t:eq(reloadedSecondPoint._vertex.offset, 0.5)
	t:eq(reloadedSecondPoint.time, Fraction(1, 2))
end

---@param t testing.T
function test.undo_before_save_persists_undone_state(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local note = EditorTestFactory.addCommittedNote(editorModel, "tap", 0.25, "key1")

	selectNote(editorModel, note)
	editorModel.noteService:deleteNotes()
	t:eq(#editorModel.notes:getNotes(), 0)

	editorModel.editorChanges:undo()
	t:eq(#editorModel.notes:getNotes(), 1)

	local loadedEditorModel = reloadThroughNoteChartLoader(editorModel)
	local notes = loadedEditorModel.notes:getNotes()
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.25)
	t:eq(notes[1].column, "key1")
end

---@param t testing.T
function test.save_updates_chart_notes_without_editor_links(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local loader = attachLoader(editorModel)
	local note = EditorTestFactory.addNote(editorModel, "hold", 0.25, "key2")

	loader:save()
	local notes = editorModel.chart.notes:getNotes()

	t:eq(#notes, 2)
	t:eq(notes[1].type, "hold")
	t:eq(notes[2].type, "hold")
	t:eq(notes[1].startNote, nil)
	t:eq(notes[1].endNote, nil)
	t:eq(notes[2].startNote, nil)
	t:eq(notes[2].endNote, nil)
end

---@param t testing.T
function test.save_updates_chart_timing_layer(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local loader = attachLoader(editorModel)
	local intervalManager = editorModel.intervalManager
	local point = editorModel:getDtpAbsolute(0.5)
	local vertex = intervalManager:split(point)
	intervalManager:update(vertex, 2)

	loader:save()
	local points = editorModel.chart.layers.main:getPointList()

	t:eq(#points, 3)
	t:eq(points[1]._vertex.offset, 0)
	t:eq(points[2]._vertex.offset, 0.5)
	t:eq(points[2].time, Fraction(1, 2))
end

return test
