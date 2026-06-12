local class = require("class")
local Fraction = require("chart.core.Fraction")
local LongEditorNote = require("rizu.editor.LongEditorNote")
local Note = require("chart.model.notes.Note")
local ShortEditorNote = require("rizu.editor.ShortEditorNote")

---@class rizu.editor.EditorNoteOpsContext
---@field getNotes fun(self: rizu.editor.EditorNoteOpsContext): chartedit.Notes
---@field getEditorChanges fun(self: rizu.editor.EditorNoteOpsContext): rizu.editor.EditorChanges
---@field getLayer fun(self: rizu.editor.EditorNoteOpsContext): chartedit.Layer
---@field getVisual fun(self: rizu.editor.EditorNoteOpsContext): chartedit.Visual

---@class rizu.editor.EditorNoteOps
---@operator call: rizu.editor.EditorNoteOps
---@field context rizu.editor.EditorNoteOpsContext
local EditorNoteOps = class()

---@param context rizu.editor.EditorNoteOpsContext
function EditorNoteOps:setContext(context)
	self.context = context
end

---@param note chart.Note
function EditorNoteOps:recordAdd(note)
	local context = self.context
	context:getEditorChanges():addNoteAdd(context:getNotes(), note)
end

---@param note chart.Note
function EditorNoteOps:recordRemove(note)
	local context = self.context
	context:getEditorChanges():addNoteRemove(context:getNotes(), note)
end

---@param notes chart.Note[]
---@return boolean found
function EditorNoteOps:hasAny(notes)
	local noteStorage = self.context:getNotes()
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

	local noteStorage = self.context:getNotes()
	for _, note in ipairs(notes) do
		noteStorage:addNote(note)
		self:recordAdd(note)
	end

	return true
end

---@param notes chart.Note[]
function EditorNoteOps:removeNotes(notes)
	local noteStorage = self.context:getNotes()
	for _, note in ipairs(notes) do
		noteStorage:removeNote(note)
		self:recordRemove(note)
	end
end

---@param selectedNotes {[chart.Note]: rizu.editor.EditorNote}
---@return number deleted
function EditorNoteOps:deleteSelected(selectedNotes)
	local editorChanges = self.context:getEditorChanges()
	editorChanges:reset()

	local count = 0
	for _, note in pairs(selectedNotes) do
		selectedNotes[note.startNote] = nil
		self:removeNotes(note:getNotes())
		count = count + 1
	end

	editorChanges:next()
	return count
end

---@param noteSkin table
---@param note rizu.editor.EditorNote
---@return rizu.editor.EditorNote
function EditorNoteOps:flipNote(noteSkin, note)
	self:removeNotes(note:getNotes())

	local flippedNote = note:clone()
	flippedNote:cloneLinkedNotes()

	local columns = noteSkin.columnsCount
	local column = columns - noteSkin:getInputColumn(note.column) + 1
	flippedNote:setColumn(noteSkin:getFirstColumnInput(column))
	self:addNotes(flippedNote:getNotes())

	return flippedNote
end

---@param selectedNotes {[chart.Note]: rizu.editor.EditorNote}
---@param noteSkin table
function EditorNoteOps:flipSelected(selectedNotes, noteSkin)
	local editorChanges = self.context:getEditorChanges()
	editorChanges:reset()

	local notes = {}
	for _, note in pairs(selectedNotes) do
		table.insert(notes, note)
	end

	for _, note in ipairs(notes) do
		selectedNotes[note.startNote] = nil
		local flippedNote = self:flipNote(noteSkin, note)
		selectedNotes[flippedNote.startNote] = flippedNote
	end

	editorChanges:next()
end

---@param note rizu.editor.EditorNote
---@param endNote chart.Note
---@param noteType chart.NoteType
function EditorNoteOps:setLong(note, endNote, noteType)
	local noteStorage = self.context:getNotes()
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
	local noteStorage = self.context:getNotes()
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
	local context = self.context
	local editorChanges = context:getEditorChanges()

	if not note.endNote then
		local startNote = note.startNote
		local p = startNote.visualPoint.point
		local endPoint = context:getLayer().points:getPoint(p:add(Fraction(1, snap)))
		local endNote = Note(context:getVisual():getPoint(endPoint), note.column, "hold", -1)

		self:setLong(note, endNote, "hold")
		editorChanges:add(
			editorChanges:command(self, "setLong", note, endNote, "hold"),
			editorChanges:command(self, "setShort", note, endNote)
		)
		return
	end

	local endNote = note.endNote
	local noteType = note.startNote.type
	self:setShort(note, endNote)
	editorChanges:add(
		editorChanges:command(self, "setShort", note, endNote),
		editorChanges:command(self, "setLong", note, endNote, noteType)
	)
end

return EditorNoteOps
