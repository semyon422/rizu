local class = require("class")
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
	self.selectedNotes = {}
	self.visual_info = VisualInfo()
end

function VisualEngine:reset()
	self:selectEnd()
	self:selectNote()
	self.notes = {}
	self.selectedNotes = {}
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
	for _, note in ipairs(self.notes) do
		note.selected = false
	end
	self.selectedNotes = {}
	self.selecting = true
end

function VisualEngine:selectEnd()
	self.selecting = false
end

---@param note rizu.editor.EditorNote?
---@param keepOthers boolean?
function VisualEngine:selectNote(note, keepOthers)
	if not note then
		for _, _note in ipairs(self.notes) do
			_note.selected = false
		end
		self.selectedNotes = {}
		return
	end
	if not note.selected then
		if not keepOthers then
			for _, _note in ipairs(self.notes) do
				_note.selected = false
			end
			self.selectedNotes = {}
		end
		note.selected = true
		self.selectedNotes[note.startNote] = note
		return
	end
	if not keepOthers then
		return
	end
	note.selected = false
	self.selectedNotes[note.startNote] = nil
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
	note.visual = self.editorModel.visual
	return note
end

function VisualEngine:update()
	local editorModel = self.editorModel
	local editor = editorModel.configModel.configs.settings.editor

	local visual_info = self.visual_info
	visual_info.time = self:getCurrentTime()
	visual_info.rate = editor.speed
	visual_info.const = self.constant

	local selectedNotes = self.selectedNotes

	local notesMap = {}
	for _, note in ipairs(self.notes) do
		notesMap[note.startNote] = note
		note.cvp = editorModel.visualPoint
		note.visual = editorModel.visual
		if note.selecting then
			note.selected = true
			selectedNotes[note.startNote] = note
		elseif self.selecting then
			note.selected = false
			selectedNotes[note.startNote] = nil
		end
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
