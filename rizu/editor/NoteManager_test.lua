local EditorChanges = require("rizu.editor.EditorChanges")
local Fraction = require("chart.core.Fraction")
local Layer = require("chart.chartedit.Layer")
local Notes = require("chart.chartedit.Notes")
local NoteManager = require("rizu.editor.NoteManager")
local Point = require("chart.chartedit.Point")
local Scroller = require("rizu.editor.Scroller")
local Visual = require("chart.chartedit.Visual")
local VisualInfo = require("rizu.engine.visual.VisualInfo")

local test = {}

local function createNoteSkin()
	return {
		columnsCount = 4,
		getInputColumn = function(_, column)
			return tonumber(column:match("^key(%d+)$"))
		end,
		getFirstColumnInput = function(_, column)
			return "key" .. column
		end,
	}
end

local function createEditorModel()
	local layer = Layer()
	layer.points:initDefault()
	local visual = Visual()
	layer.visuals.main = visual

	local editorChanges = EditorChanges()
	local noteManager = NoteManager()
	local scroller = Scroller()

	local editorModel = {
		layer = layer,
		visual = visual,
		notes = Notes(),
		editorChanges = editorChanges,
		noteManager = noteManager,
		scroller = scroller,
		session = {
			point = layer.points:getFirstPoint():clone(Point()),
			noteSkin = createNoteSkin(),
		},
		settings = {
			snap = 4,
			tool = "ShortNote",
			lockSnap = true,
		},
		visualEngine = {
			notes = {},
			selectedNotes = {},
			visual_info = VisualInfo(),
			reset_count = 0,
		},
	}

	function editorModel:getSettings()
		return self.settings
	end

	function editorModel:getDtpAbsolute(time)
		local point = self.layer.points:interpolateAbsolute(self.settings.snap, time)
		point.absoluteTime = time
		return point
	end

	function editorModel:setSessionTime(time)
		self:getDtpAbsolute(time):clone(self.session.point)
	end

	function editorModel:getMouseTime()
		return self.mouseTime or 0
	end

	function editorModel.visualEngine:reset()
		self.notes = {}
		self.selectedNotes = {}
		self.reset_count = self.reset_count + 1
	end

	function editorModel.visualEngine:selectNote(note)
		self.selectedNotes = {}
		if note then
			self.selectedNotes[note.startNote] = note
		end
	end

	editorChanges.editorModel = editorModel
	noteManager.editorModel = editorModel
	scroller.editorModel = editorModel

	return editorModel
end

local function getNotes(editorModel)
	return editorModel.notes:getNotes()
end

local function selectNote(editorModel, note)
	editorModel.visualEngine.selectedNotes = {
		[note.startNote] = note,
	}
end

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
	selectNote(editorModel, note)

	editorModel.noteManager:flipNotes()

	local notes = getNotes(editorModel)
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

return test
