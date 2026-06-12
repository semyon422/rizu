local class = require("class")
local EditorSelection = require("rizu.editor.EditorSelection")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")
local VisualInfo = require("rizu.engine.visual.VisualInfo")

---@class rizu.editor.VisualEngineContext
---@field getSessionTime fun(): number
---@field getEditorSettings fun(): table
---@field getVisualPoint fun(): chartedit.VisualPoint?
---@field getVisual fun(): chartedit.Visual?
---@field getNotes fun(): chartedit.Notes
---@field getIterRange fun(): number, number
---@field getEditorNoteContext fun(): rizu.editor.EditorNoteContext

---@class rizu.editor.VisualEngine
---@operator call: rizu.editor.VisualEngine
---@field selectedNotes {[chart.Note]: rizu.editor.EditorNote}
---@field context rizu.editor.VisualEngineContext
---@field visual_info rizu.VisualInfo
local VisualEngine = class()

function VisualEngine:new()
	self.notes = {}
	self.selection = EditorSelection()
	self.selectedNotes = self.selection.notes
	self.visual_info = VisualInfo()
end

---@param context rizu.editor.VisualEngineContext
function VisualEngine:setContext(context)
	self.context = context
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
	return self.context.getSessionTime()
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
	local editor = self.context.getEditorSettings()
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
	note:setContext(self.context.getEditorNoteContext())
	note.visualEngine = self
	note.column = column
	note.cvp = self.context.getVisualPoint()
	note.visual = self.context.getVisual()
	return note
end

function VisualEngine:update()
	local context = self.context
	local editor = context.getEditorSettings()

	local visual_info = self.visual_info
	visual_info.time = self:getCurrentTime()
	visual_info.rate = editor.speed
	visual_info.const = self.constant

	local selectedNotes = self.selection.notes

	local notesMap = {}
	self.selection:updateVisible(self.notes)
	for _, note in ipairs(self.notes) do
		notesMap[note.startNote] = note
		note.cvp = context.getVisualPoint()
		note.visual = context.getVisual()
	end

	local newNotes = {}
	self.notes = newNotes

	for _note, column in context.getNotes():iterLinked(context.getIterRange()) do
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
