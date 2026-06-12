local class = require("class")
local NoteDragSession = require("rizu.editor.NoteDragSession")
local NoteClipboard = require("rizu.editor.NoteClipboard")
local EditorNoteOps = require("rizu.editor.EditorNoteOps")
local NoteCreator = require("rizu.editor.NoteCreator")

---@class rizu.editor.NoteManager
---@operator call: rizu.editor.NoteManager
local NoteManager = class()

function NoteManager:new()
	self.dragSession = NoteDragSession(self)
	self.grabbedNotes = self.dragSession.grabbedNotes
	self.clipboard = NoteClipboard(self)
	self.creator = NoteCreator(self)
	self.noteOps = EditorNoteOps()
end

---@return rizu.editor.EditorNoteOps
function NoteManager:getNoteOps()
	self.noteOps.editorModel = self.editorModel
	return self.noteOps
end

---@return number
function NoteManager:getColumnOver()
	if self.columnOver then
		return self.columnOver
	end
	local mx, _my = self.editorModel.getMousePosition()
	local noteSkin = self.editorModel.session.noteSkin
	return noteSkin:getInverseColumnPosition(mx)
end

function NoteManager:update()
	self.dragSession:update()
end

---@param cut boolean?
function NoteManager:copyNotes(cut)
	self.clipboard:copy(cut)
	self.copiedNotes = self.clipboard.copiedNotes
end

---@return number
function NoteManager:deleteNotes()
	return self:getNoteOps():deleteSelected(self.editorModel.visualEngine.selectedNotes)
end

function NoteManager:changeType()
	---@type rizu.editor.EditorModel
	local editorModel = self.editorModel
	local editor = editorModel:getSettings()

	editorModel.editorChanges:reset()

	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		self:getNoteOps():changeType(note, editor.snap)
	end

	self.editorModel.visualEngine:reset()

	self.editorModel.editorChanges:next()
end

function NoteManager:pasteNotes()
	self.clipboard:paste()
	self.copiedNotes = self.clipboard.copiedNotes
end

---@param part string
---@param mouseTime number
function NoteManager:grabNotes(part, mouseTime)
	self.dragSession:grab(part, mouseTime)
end

---@param mouseTime number
function NoteManager:dropNotes(mouseTime)
	self.dragSession:drop(mouseTime)
end

---@param note rizu.editor.EditorNote
function NoteManager:_removeNote(note)
	self.editorModel.visualEngine.selectedNotes[note.startNote] = nil
	self:getNoteOps():removeNotes(note:getNotes())
end

---@param note rizu.editor.EditorNote
function NoteManager:removeNote(note)
	self.editorModel.editorChanges:reset()
	self:_removeNote(note)
	self.editorModel.editorChanges:next()
end

---@param notes chart.Note[]
function NoteManager:_addNotes(notes)
	return self:getNoteOps():addNotes(notes)
end

---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote?
function NoteManager:newNote(noteType, absoluteTime, column)
	return self.creator:newNote(noteType, absoluteTime, column)
end

---@param absoluteTime number
---@param column string
function NoteManager:addNote(absoluteTime, column)
	self.creator:addNote(absoluteTime, column)
end

function NoteManager:flipNotes()
	local editorModel = self.editorModel
	local noteSkin = self.editorModel.session.noteSkin

	self:getNoteOps():flipSelected(editorModel.visualEngine.selectedNotes, noteSkin)
end

return NoteManager
