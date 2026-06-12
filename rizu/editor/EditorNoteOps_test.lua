local EditorChanges = require("rizu.editor.EditorChanges")
local EditorNoteOps = require("rizu.editor.EditorNoteOps")
local Layer = require("chart.chartedit.Layer")
local Note = require("chart.model.notes.Note")
local Notes = require("chart.chartedit.Notes")
local Visual = require("chart.chartedit.Visual")

local test = {}

local function createContext()
	local layer = Layer()
	layer.points:initDefault()
	local visual = Visual()
	local point = visual:getPoint(layer.points:getFirstPoint())
	local note = Note(point, "key1", "tap")

	local editorChanges = EditorChanges()
	local editorModel = {
		layer = layer,
		visual = visual,
		notes = Notes(),
		editorChanges = editorChanges,
		visualEngine = {
			reset = function() end,
		},
	}
	function editorModel:getVisual()
		return self.visual
	end
	editorChanges:setContext({
		resetVisual = function()
			editorModel.visualEngine:reset()
		end,
	})

	local ops = EditorNoteOps()
	ops:setContext({
		notes = editorModel.notes,
		editorChanges = editorModel.editorChanges,
		getLayer = function()
			return editorModel.layer
		end,
		getVisual = function()
			return editorModel:getVisual()
		end,
	})

	return ops, editorModel, note
end

---@param t testing.T
function test.add_duplicate_remove(t)
	local ops, editorModel, note = createContext()

	t:eq(ops:addNotes({note}), true)
	t:eq(ops:addNotes({note}), false)
	t:eq(#editorModel.notes:getNotes(), 1)

	ops:removeNotes({note})
	t:eq(#editorModel.notes:getNotes(), 0)
end

---@param t testing.T
function test.undo_redo(t)
	local ops, editorModel, note = createContext()

	ops:addNotes({note})
	editorModel.editorChanges:next()

	t:eq(#editorModel.notes:getNotes(), 1)

	editorModel.editorChanges:undo()
	t:eq(#editorModel.notes:getNotes(), 0)

	editorModel.editorChanges:redo()
	t:eq(#editorModel.notes:getNotes(), 1)
end

return test
