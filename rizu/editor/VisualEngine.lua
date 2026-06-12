local class = require("class")
local EditorSelection = require("rizu.editor.EditorSelection")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")
local VisualInfo = require("rizu.engine.visual.VisualInfo")

---@class rizu.editor.VisualEngine
---@operator call: rizu.editor.VisualEngine
---@field selectedNotes {[chart.Note]: rizu.editor.EditorNote}
---@field editorModel rizu.editor.EditorModel
---@field visual_info rizu.VisualInfo
local VisualEngine = class()

function VisualEngine:new()
	self.notes = {}
	self.selection = EditorSelection()
	self.selectedNotes = self.selection.notes
	self.visual_info = VisualInfo()
end

function VisualEngine:reset()
	self.selection:finish()
	self.selection:clear(self.notes)
	self.notes = {}
	self.selectedNotes = self.selection.notes
end

VisualEngine.longNoteShortening = 0
VisualEngine.constant = false
VisualEngine.range = {-1, 1}

---@return number
function VisualEngine:getCurrentTime()
	return self.editorModel.session.point.absoluteTime
end

---@return number
function VisualEngine:getInputOffset()
	return 0
end

---@return number
function VisualEngine:getVisualOffset()
	return 0
end

---@return number
function VisualEngine:getVisualTimeRate()
	local editor = self.editorModel.configModel.configs.settings.editor
	return editor.speed
end

---@param note chart.Note
---@return rizu.LogicNote?
function VisualEngine:getLogicalNote(note)
	return
end

function VisualEngine:selectStart()
	self.selection:start(self.notes)
	self.selectedNotes = self.selection.notes
end

function VisualEngine:selectEnd()
	self.selection:finish()
end

---@param note rizu.editor.EditorNote?
---@param keepOthers boolean?
function VisualEngine:selectNote(note, keepOthers)
	self.selection:select(note, keepOthers, self.notes)
	self.selectedNotes = self.selection.notes
end

---@param _note chart.LinkedNote
---@param column chart.Column
---@return rizu.editor.EditorNote?
function VisualEngine:newNote(_note, column)
	local note = EditorNoteFactory:newNote(_note, self.visual_info)
	if not note then
		return
	end
	note.editorModel = self.editorModel
	note.visualEngine = self
	note.column = column
	note.cvp = self.editorModel.visualPoint
	note.visual = self.editorModel:getVisual()
	return note
end

function VisualEngine:update()
	local editorModel = self.editorModel
	local editor = editorModel.configModel.configs.settings.editor

	local visual_info = self.visual_info
	visual_info.time = self:getCurrentTime()
	visual_info.rate = editor.speed
	visual_info.const = self.constant

	local selectedNotes = self.selection.notes

	local notesMap = {}
	self.selection:updateVisible(self.notes)
	for _, note in ipairs(self.notes) do
		notesMap[note.startNote] = note
		note.cvp = editorModel.visualPoint
		note.visual = editorModel:getVisual()
	end

	local newNotes = {}
	self.notes = newNotes

	for _note, column in editorModel.notes:iterLinked(editorModel:getIterRange()) do
		local startNote = _note.startNote
		local note = notesMap[startNote] or
			selectedNotes[startNote] or
			self:newNote(_note, column)
		if note then
			table.insert(newNotes, note)
			note:update()
		end
	end
end

return VisualEngine
