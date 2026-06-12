local EditorChanges = require("rizu.editor.EditorChanges")
local IntervalManager = require("rizu.editor.IntervalManager")
local Layer = require("chart.chartedit.Layer")
local Notes = require("chart.chartedit.Notes")
local NoteManager = require("rizu.editor.NoteManager")
local Point = require("chart.chartedit.Point")
local Scroller = require("rizu.editor.Scroller")
local Visual = require("chart.chartedit.Visual")
local VisualInfo = require("rizu.engine.visual.VisualInfo")

local EditorTestFactory = {}

---@return table
function EditorTestFactory.createNoteSkin()
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

---@return rizu.editor.EditorModel
function EditorTestFactory.createEditorModel()
	local layer = Layer()
	layer.points:initDefault()
	local notes = Notes()
	local visual = Visual()
	visual.on_remove = function(vp)
		notes:removeAll(vp)
	end
	layer.visuals.main = visual

	local editorChanges = EditorChanges()
	local intervalManager = IntervalManager()
	local noteManager = NoteManager()
	local scroller = Scroller()

	---@type rizu.editor.EditorModel
	local editorModel = {
		layer = layer,
		visual = visual,
		notes = notes,
		editorChanges = editorChanges,
		intervalManager = intervalManager,
		noteManager = noteManager,
		scroller = scroller,
		session = {
			point = layer.points:getFirstPoint():clone(Point()),
			noteSkin = EditorTestFactory.createNoteSkin(),
		},
		settings = {
			snap = 4,
			tool = "ShortNote",
			lockSnap = true,
		},
		isMultiSelectRequested = function()
			return false
		end,
		getMousePosition = function()
			return 0, 0
		end,
		selectRegion = function() end,
		unselectRegion = function() end,
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
	intervalManager.editorModel = editorModel
	noteManager.editorModel = editorModel
	scroller.editorModel = editorModel

	return editorModel
end

---@param editorModel rizu.editor.EditorModel
---@return chart.Note[]
function EditorTestFactory.getNotes(editorModel)
	return editorModel.notes:getNotes()
end

---@param editorModel rizu.editor.EditorModel
---@param note rizu.editor.EditorNote
function EditorTestFactory.selectNote(editorModel, note)
	editorModel.visualEngine.selectedNotes = {
		[note.startNote] = note,
	}
end

return EditorTestFactory
