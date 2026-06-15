local EditorTestFactory = require("rizu.editor.test.EditorTestFactory")
local Fraction = require("chart.core.Fraction")

local test = {}

local createEditorModel = EditorTestFactory.createEditorModel
local getNotes = EditorTestFactory.getNotes

---@param editorModel rizu.editor.EditorModel
---@param time number
---@return chartedit.Point
local function pointAt(editorModel, time)
	local point = editorModel:getDtpAbsolute(time)
	return editorModel.layer.points:getPoint(point:unpack())
end

---@param editorModel rizu.editor.EditorModel
---@param time number
---@return chartedit.Point
local function visualPointAt(editorModel, time)
	local point = pointAt(editorModel, time)
	editorModel.visual:getPoint(point)
	return point
end

---@param editorModel rizu.editor.EditorModel
---@param absolute_time number
---@return boolean
local function containsPointAt(editorModel, absolute_time)
	local point = editorModel.layer.points:getFirstPoint()
	while point do
		if math.abs(point.absoluteTime - absolute_time) < 1e-9 then
			return true
		end
		point = point.next
	end
	return false
end

---@param editorModel rizu.editor.EditorModel
---@param start_time number
---@return rizu.editor.LongEditorNote
local function addLongNote(editorModel, start_time)
	local note = EditorTestFactory.addNote(editorModel, "hold", start_time, "key1")
	return note
end

---@param t testing.T
function test.split_undo_redo(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local point = pointAt(editorModel, 0.5)

	local vertex = intervalManager:split(point)

	t:eq(point._vertex, vertex)
	t:eq(point.vertex.offset, 0.5)
	t:eq(point.time, Fraction(1, 2))

	editorModel.editorChanges:undo()
	t:eq(point._vertex, nil)
	t:eq(point.vertex.offset, 0)

	editorModel.editorChanges:redo()
	t:eq(point._vertex.offset, 0.5)
	t:eq(point.vertex.offset, 0.5)
end

---@param t testing.T
function test.merge_undo_redo(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local point = pointAt(editorModel, 0.5)
	intervalManager:split(point)
	editorModel.editorChanges:reset()

	intervalManager:merge(point)

	t:eq(point._vertex, nil)
	t:eq(point.vertex.offset, 0)

	editorModel.editorChanges:undo()
	t:eq(point._vertex.offset, 0.5)
	t:eq(point.vertex.offset, 0.5)

	editorModel.editorChanges:redo()
	t:eq(point._vertex, nil)
	t:eq(point.vertex.offset, 0)
end

---@param t testing.T
function test.update_undo_redo(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local firstPoint = editorModel.layer.points:getFirstPoint()
	local vertex = firstPoint._vertex

	intervalManager:update(vertex, 2)

	t:eq(vertex.beats, 2)

	editorModel.editorChanges:undo()
	t:eq(vertex.beats, 1)

	editorModel.editorChanges:redo()
	t:eq(vertex.beats, 2)
end

---@param t testing.T
function test.grab_move_drop_undo_redo(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local lastPoint = editorModel.layer.points:getLastPoint()
	local vertex = lastPoint._vertex

	intervalManager:grab(vertex)
	intervalManager:moveGrabbed(1.5)
	intervalManager:drop()

	t:eq(vertex.offset, 1.5)
	t:eq(intervalManager:isGrabbed(), false)

	editorModel.editorChanges:undo()
	t:eq(vertex.offset, 1)

	editorModel.editorChanges:redo()
	t:eq(vertex.offset, 1.5)
end

---@param t testing.T
function test.chained_splits_undo_redo(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local p25 = pointAt(editorModel, 0.25)
	local p50 = pointAt(editorModel, 0.5)

	intervalManager:split(p25)
	intervalManager:split(p50)

	t:eq(p25._vertex.offset, 0.25)
	t:eq(p50._vertex.offset, 0.5)

	editorModel.editorChanges:undo()
	t:eq(p50._vertex, nil)
	t:eq(p25._vertex.offset, 0.25)

	editorModel.editorChanges:undo()
	t:eq(p25._vertex, nil)
	t:eq(p25.vertex.offset, 0)

	editorModel.editorChanges:redo()
	t:eq(p25._vertex.offset, 0.25)
	t:eq(p50._vertex, nil)

	editorModel.editorChanges:redo()
	t:eq(p50._vertex.offset, 0.5)
end

---@param t testing.T
function test.update_shrink_restores_removed_points(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local firstPoint = editorModel.layer.points:getFirstPoint()
	local vertex = firstPoint._vertex

	intervalManager:update(vertex, 3)
	editorModel.editorChanges:reset()

	local p50 = visualPointAt(editorModel, 0.5)
	local p75 = visualPointAt(editorModel, 0.75)

	intervalManager:update(vertex, 1)

	t:eq(vertex.beats, 1)
	t:eq(containsPointAt(editorModel, 0.5), false)
	t:eq(containsPointAt(editorModel, 0.75), false)

	editorModel.editorChanges:undo()
	t:eq(vertex.beats, 3)
	t:eq(containsPointAt(editorModel, 0.5), true)
	t:eq(containsPointAt(editorModel, 0.75), true)
	t:ne(editorModel.visual.p2vp[pointAt(editorModel, 0.5)], nil)
	t:ne(editorModel.visual.p2vp[pointAt(editorModel, 0.75)], nil)
end

---@param t testing.T
function test.update_shrink_undo_restores_removed_notes(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local firstPoint = editorModel.layer.points:getFirstPoint()
	local vertex = firstPoint._vertex

	intervalManager:update(vertex, 3)
	editorModel.editorChanges:reset()

	local note = EditorTestFactory.addNote(editorModel, "tap", 0.75, "key1")
	editorModel.editorChanges:reset()

	intervalManager:update(vertex, 1)

	t:eq(vertex.beats, 1)
	t:eq(#getNotes(editorModel), 0)

	editorModel.editorChanges:undo()
	local notes = getNotes(editorModel)
	t:eq(vertex.beats, 3)
	t:eq(#notes, 1)
	t:eq(notes[1]:getTime(), 0.75)
	t:eq(notes[1].visualPoint.point.absoluteTime, 0.75)
end

---@param t testing.T
function test.update_shrink_undo_restores_long_note_tail(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local vertex = editorModel.layer.points:getFirstPoint()._vertex

	intervalManager:update(vertex, 3)
	editorModel.editorChanges:reset()

	local note = addLongNote(editorModel, 0.25)
	local startTime = note.startNote:getTime()
	local endTime = note.endNote:getTime()
	editorModel.editorChanges:reset()

	intervalManager:update(vertex, 1)
	t:eq(#getNotes(editorModel), 1)

	editorModel.editorChanges:undo()
	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), startTime)
	t:eq(notes[2]:getTime(), endTime)

	editorModel.editorChanges:redo()
	t:eq(#getNotes(editorModel), 1)
end

---@param t testing.T
function test.update_shrink_undo_restores_long_note_head(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local vertex = editorModel.layer.points:getFirstPoint()._vertex

	intervalManager:update(vertex, 3)
	editorModel.editorChanges:reset()

	local note = addLongNote(editorModel, 0.75)
	note.endNote.visualPoint = editorModel.visual:getPoint(pointAt(editorModel, 1.25))
	editorModel.notes:removeNote(note.endNote)
	editorModel.notes:addNote(note.endNote)
	local startTime = note.startNote:getTime()
	local endTime = note.endNote:getTime()
	editorModel.editorChanges:reset()

	intervalManager:update(vertex, 1)
	t:eq(#getNotes(editorModel), 1)

	editorModel.editorChanges:undo()
	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1]:getTime(), startTime)
	t:eq(notes[2]:getTime(), endTime)
	t:eq(note.startNote.endNote, note.endNote)
	t:eq(note.endNote.startNote, note.startNote)

	editorModel.editorChanges:redo()
	t:eq(#getNotes(editorModel), 1)
end

---@param t testing.T
function test.update_shrink_undo_redo_restores_long_note_both_ends(t)
	local editorModel = createEditorModel()
	local intervalManager = editorModel.intervalManager
	local vertex = editorModel.layer.points:getFirstPoint()._vertex

	intervalManager:update(vertex, 3)
	editorModel.editorChanges:reset()

	local note = addLongNote(editorModel, 0.5)
	local startTime = note.startNote:getTime()
	local endTime = note.endNote:getTime()
	editorModel.editorChanges:reset()

	intervalManager:update(vertex, 1)
	t:eq(#getNotes(editorModel), 0)

	editorModel.editorChanges:undo()
	local notes = getNotes(editorModel)
	t:eq(#notes, 2)
	t:eq(notes[1], note.startNote)
	t:eq(notes[2], note.endNote)
	t:eq(notes[1]:getTime(), startTime)
	t:eq(notes[2]:getTime(), endTime)

	editorModel.editorChanges:redo()
	t:eq(#getNotes(editorModel), 0)
end

return test
