local class = require("class")
local Fraction = require("chart.core.Fraction")
local LongEditorNote = require("rizu.editor.LongEditorNote")
local Note = require("chart.model.notes.Note")
local ShortEditorNote = require("rizu.editor.ShortEditorNote")

---@class rizu.editor.EditorNoteOps
---@operator call: rizu.editor.EditorNoteOps
---@field editorModel rizu.editor.EditorModel
local EditorNoteOps = class()

---@param note chart.Note
function EditorNoteOps:recordAdd(note)
	local notes = self.editorModel.notes
	self.editorModel.editorChanges:add(
		{notes, "addNote", notes, note},
		{notes, "removeNote", notes, note}
	)
end

---@param note chart.Note
function EditorNoteOps:recordRemove(note)
	local notes = self.editorModel.notes
	self.editorModel.editorChanges:add(
		{notes, "removeNote", notes, note},
		{notes, "addNote", notes, note}
	)
end

---@param notes chart.Note[]
---@return boolean found
function EditorNoteOps:hasAny(notes)
	local noteStorage = self.editorModel.notes
	for _, note in ipairs(notes) do
		if noteStorage:findNote(note) then
			return true
		end
	end
	return false
end

---@param notes chart.Note[]
---@return boolean added
function EditorNoteOps:addNotes(notes)
	if self:hasAny(notes) then
		return false
	end

	local noteStorage = self.editorModel.notes
	for _, note in ipairs(notes) do
		noteStorage:addNote(note)
		self:recordAdd(note)
	end

	return true
end

---@param notes chart.Note[]
function EditorNoteOps:removeNotes(notes)
	local noteStorage = self.editorModel.notes
	for _, note in ipairs(notes) do
		noteStorage:removeNote(note)
		self:recordRemove(note)
	end
end

---@param note rizu.editor.EditorNote
---@param endNote chart.Note
---@param noteType chart.NoteType
function EditorNoteOps:setLong(note, endNote, noteType)
	local noteStorage = self.editorModel.notes
	local startNote = note.startNote

	startNote.type = noteType
	startNote.weight = 1
	startNote.endNote = endNote

	endNote.type = noteType
	endNote.weight = -1
	endNote.column = startNote.column
	endNote.startNote = startNote

	note.endNote = endNote
	setmetatable(note, LongEditorNote)

	if not noteStorage:findNote(endNote) then
		noteStorage:addNote(endNote)
	end
end

---@param note rizu.editor.EditorNote
---@param endNote chart.Note
function EditorNoteOps:setShort(note, endNote)
	local noteStorage = self.editorModel.notes
	local startNote = note.startNote

	noteStorage:removeNote(endNote)

	startNote.type = "tap"
	startNote.weight = 0
	startNote.endNote = nil

	endNote.type = "ignore"
	endNote.weight = 0
	endNote.startNote = nil

	note.endNote = nil
	setmetatable(note, ShortEditorNote)
end

---@param note rizu.editor.EditorNote
---@param snap integer
function EditorNoteOps:changeType(note, snap)
	local editorModel = self.editorModel

	if not note.endNote then
		local startNote = note.startNote
		local p = startNote.visualPoint.point
		local endPoint = editorModel.layer.points:getPoint(p:add(Fraction(1, snap)))
		local endNote = Note(editorModel.visual:getPoint(endPoint), note.column, "hold", -1)

		self:setLong(note, endNote, "hold")
		editorModel.editorChanges:add(
			{self, "setLong", self, note, endNote, "hold"},
			{self, "setShort", self, note, endNote}
		)
		return
	end

	local endNote = note.endNote
	local noteType = note.startNote.type
	self:setShort(note, endNote)
	editorModel.editorChanges:add(
		{self, "setShort", self, note, endNote},
		{self, "setLong", self, note, endNote, noteType}
	)
end

return EditorNoteOps
