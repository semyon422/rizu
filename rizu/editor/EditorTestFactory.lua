local EditorChanges = require("rizu.editor.EditorChanges")
local IntervalManager = require("rizu.editor.IntervalManager")
local Layer = require("chart.chartedit.Layer")
local Notes = require("chart.chartedit.Notes")
local EditorNoteService = require("rizu.editor.EditorNoteService")
local Point = require("chart.chartedit.Point")
local Scroller = require("rizu.editor.Scroller")
local Visual = require("chart.chartedit.Visual")
local VisualInfo = require("rizu.engine.visual.VisualInfo")
local EditorModelContext = require("rizu.editor.EditorModelContext")

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
	local noteService = EditorNoteService()
	local scroller = Scroller()
	local point = layer.points:getFirstPoint():clone(Point())
	local noteSkin = EditorTestFactory.createNoteSkin()

	---@type rizu.editor.EditorModel
	local editorModel = {
		layer = layer,
		visual = visual,
		notes = notes,
		editorChanges = editorChanges,
		intervalManager = intervalManager,
		noteService = noteService,
		scroller = scroller,
		point = point,
		noteSkin = noteSkin,
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

	function editorModel:getVisual()
		return self.visual
	end

	function editorModel:setSessionTime(time)
		self:getDtpAbsolute(time):clone(self.point)
	end

	function editorModel:setTime(time)
		self:setSessionTime(time)
	end

	function editorModel:getSessionTime()
		return self.point.absoluteTime
	end

	function editorModel:getPoint()
		return self.point
	end

	function editorModel:getNoteSkin()
		return self.noteSkin
	end

	function editorModel:setNoteSkin(noteSkin)
		self.noteSkin = noteSkin
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

	editorModel.context = EditorModelContext(editorModel)
	editorChanges:setContext(editorModel.context:getEditorChangesContext())
	intervalManager:setContext(editorModel.context:getIntervalManagerContext())
	noteService:setContext(editorModel.context:getNoteServiceContext())
	scroller:setContext(editorModel.context:getScrollerContext())

	return editorModel
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.NoteChartLoaderContext
function EditorTestFactory.createNoteChartLoaderContext(editorModel)
	return {
		getChart = function()
			return editorModel.chart
		end,
		getLayer = function()
			return editorModel.layer
		end,
		getNotes = function()
			return editorModel.notes
		end,
	}
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.EditorChangesContext
function EditorTestFactory.createEditorChangesContext(editorModel)
	return {
		resetVisual = function()
			editorModel.visualEngine:reset()
		end,
	}
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.VisualEngineContext
function EditorTestFactory.createVisualEngineContext(editorModel)
	return {
		getSessionTime = function()
			return editorModel:getSessionTime()
		end,
		getEditorSettings = function()
			return editorModel.configModel.configs.settings.editor
		end,
		getVisualPoint = function()
			return editorModel.visualPoint
		end,
		getVisual = function()
			return editorModel:getVisual()
		end,
		getNotes = function()
			return editorModel.notes
		end,
		getIterRange = function()
			return editorModel:getIterRange()
		end,
		getEditorNoteContext = function()
			return EditorTestFactory.createEditorNoteContext(editorModel)
		end,
	}
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.EditorNoteContext
function EditorTestFactory.createEditorNoteContext(editorModel)
	return {
		getDtpAbsolute = function(absoluteTime)
			return editorModel:getDtpAbsolute(absoluteTime)
		end,
		getLayer = function()
			return editorModel.layer
		end,
		getVisual = function()
			return editorModel:getVisual()
		end,
		getNextSnapIntervalTime = function(point, delta)
			return editorModel.scroller:getNextSnapIntervalTime(point, delta)
		end,
	}
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.EditorNoteServiceContext
function EditorTestFactory.createEditorNoteServiceContext(editorModel)
	return {
		columnService = {
			getMousePosition = function()
				return editorModel.getMousePosition()
			end,
			getNoteSkin = function()
				return editorModel:getNoteSkin()
			end,
		},
		commandService = {
			getSelectedNotes = function()
				return editorModel.visualEngine.selectedNotes
			end,
			editorChanges = editorModel.editorChanges,
			getSettings = function()
				return editorModel:getSettings()
			end,
			getNoteSkin = function()
				return editorModel:getNoteSkin()
			end,
			resetVisual = function()
				editorModel.visualEngine:reset()
			end,
			getNoteOpsContext = function()
				return {
					notes = editorModel.notes,
					editorChanges = editorModel.editorChanges,
					getLayer = function()
						return editorModel.layer
					end,
					getVisual = function()
						return editorModel:getVisual()
					end,
				}
			end,
		},
		dragService = {
			getNoteSkin = function()
				return editorModel:getNoteSkin()
			end,
			getSettings = function()
				return editorModel:getSettings()
			end,
			editorChanges = editorModel.editorChanges,
			getSelectedNotes = function()
				return editorModel.visualEngine.selectedNotes
			end,
			getMouseTime = function()
				return editorModel:getMouseTime()
			end,
		},
		clipboardService = {
			getSelectedNotes = function()
				return editorModel.visualEngine.selectedNotes
			end,
			editorChanges = editorModel.editorChanges,
			getPoint = function()
				return editorModel:getPoint()
			end,
		},
		createService = {
			getVisualInfo = function()
				return editorModel.visualEngine.visual_info
			end,
			getEditorNoteContext = function()
				return EditorTestFactory.createEditorNoteContext(editorModel)
			end,
			getVisualEngine = function()
				return editorModel.visualEngine
			end,
			getSettings = function()
				return editorModel:getSettings()
			end,
			selectNote = function(note)
				editorModel.visualEngine:selectNote(note)
			end,
			getMouseTime = function()
				return editorModel:getMouseTime()
			end,
		},
	}
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.IntervalManagerContext
function EditorTestFactory.createIntervalManagerContext(editorModel)
	return {
		getLayer = function()
			return editorModel.layer
		end,
		getNotes = function()
			return editorModel.notes
		end,
		editorChanges = editorModel.editorChanges,
	}
end

---@param editorModel rizu.editor.EditorModel
---@return rizu.editor.ScrollerContext
function EditorTestFactory.createScrollerContext(editorModel)
	return {
		getDtpAbsolute = function(absoluteTime)
			return editorModel:getDtpAbsolute(absoluteTime)
		end,
		getSessionTime = function()
			return editorModel:getSessionTime()
		end,
		getPoint = function()
			return editorModel:getPoint()
		end,
		setSessionPoint = function(sessionPoint)
			sessionPoint:clone(editorModel.point)
		end,
		setTime = function(time)
			editorModel:setSessionTime(time)
		end,
		isIntervalGrabbed = function()
			return false
		end,
		interpolateFraction = function(vertex, time)
			return editorModel.layer.points:interpolateFraction(vertex, time)
		end,
		getSettings = function()
			return editorModel:getSettings()
		end,
	}
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

---@param editorModel rizu.editor.EditorModel
---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote
function EditorTestFactory.createNote(editorModel, noteType, absoluteTime, column)
	return assert(editorModel.noteService.createService:newNote(noteType, absoluteTime, column))
end

---@param editorModel rizu.editor.EditorModel
---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote
function EditorTestFactory.addNote(editorModel, noteType, absoluteTime, column)
	local note = EditorTestFactory.createNote(editorModel, noteType, absoluteTime, column)
	editorModel.noteService.commandService:addNotes(note:getNotes())
	return note
end

---@param editorModel rizu.editor.EditorModel
---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote
function EditorTestFactory.addCommittedNote(editorModel, noteType, absoluteTime, column)
	local note = EditorTestFactory.addNote(editorModel, noteType, absoluteTime, column)
	editorModel.editorChanges:next()
	return note
end

---@param editorModel rizu.editor.EditorModel
---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote
function EditorTestFactory.addSelectedNote(editorModel, noteType, absoluteTime, column)
	local note = EditorTestFactory.addNote(editorModel, noteType, absoluteTime, column)
	EditorTestFactory.selectNote(editorModel, note)
	return note
end

---@param editorModel rizu.editor.EditorModel
---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote
function EditorTestFactory.addCommittedSelectedNote(editorModel, noteType, absoluteTime, column)
	local note = EditorTestFactory.addCommittedNote(editorModel, noteType, absoluteTime, column)
	EditorTestFactory.selectNote(editorModel, note)
	return note
end

return EditorTestFactory
