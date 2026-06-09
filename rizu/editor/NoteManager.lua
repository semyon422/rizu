local class = require("class")
local EditorNoteOps = require("rizu.editor.EditorNoteOps")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")

---@class rizu.editor.NoteManager
---@operator call: rizu.editor.NoteManager
local NoteManager = class()

function NoteManager:new()
	self.grabbedNotes = {}
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
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local noteSkin = self.editorModel.session.noteSkin
	return noteSkin:getInverseColumnPosition(mx)
end

function NoteManager:update()
	local editor = self.editorModel:getSettings()
	local noteSkin = self.editorModel.session.noteSkin

	for _, note in ipairs(self.grabbedNotes) do
		note:update()
		local time = self.editorModel:getMouseTime()
		if not editor.lockSnap then
			note:updateGrabbed(time)
		end
		local column = self:getColumnOver()
		if column then
			column = column - note.grabbedDeltaColumn
			note:setColumn(noteSkin:getFirstColumnInput(column))
		end
	end
end

---@param cut boolean?
function NoteManager:copyNotes(cut)
	if cut then
		self.editorModel.editorChanges:reset()
	end

	self.copiedNotes = {}
	local copyPoint

	for _, note in pairs(self.editorModel.visualEngine.selectedNotes) do
		if not copyPoint or note.startNote.visualPoint.point < copyPoint then
			copyPoint = note.startNote.visualPoint.point
		end
		table.insert(self.copiedNotes, note)
		if cut then
			self:_removeNote(note)
		end
	end

	for _, note in ipairs(self.copiedNotes) do
		note:copy(copyPoint)
	end
	if cut then
		self.editorModel.editorChanges:next()
	end
end

---@return number
function NoteManager:deleteNotes()
	self.editorModel.editorChanges:reset()
	local c = 0

	for n, note in pairs(self.editorModel.visualEngine.selectedNotes) do
		self:_removeNote(note)
		c = c + 1
	end
	self.editorModel.editorChanges:next()
	return c
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
	local copiedNotes = self.copiedNotes
	if not copiedNotes then
		return
	end

	self.editorModel.editorChanges:reset()
	local point = self.editorModel.session.point
	for _, note in ipairs(copiedNotes) do
		self:_addNotes(note:paste(point))
	end
	self.editorModel.editorChanges:next()
end

---@param part string
---@param mouseTime number
function NoteManager:grabNotes(part, mouseTime)
	local noteSkin = self.editorModel.session.noteSkin
	local editor = self.editorModel:getSettings()

	self.grabbedNotes = {}
	self.editorModel.editorChanges:reset()
	local column = self:getColumnOver()
	for _, note in pairs(self.editorModel.visualEngine.selectedNotes) do
		local _column = noteSkin:getInputColumn(note.column)
		if _column then
			table.insert(self.grabbedNotes, note)
			self:_removeNote(note)
			note:grab(mouseTime, part, column - _column, editor.lockSnap)
		end
	end
end

---@param mouseTime number
function NoteManager:dropNotes(mouseTime)
	local editor = self.editorModel:getSettings()
	local grabbedNotes = self.grabbedNotes
	self.grabbedNotes = {}
	local t = mouseTime

	for _, note in ipairs(grabbedNotes) do
		if not editor.lockSnap then
			note:drop(t)
		end
		self:_addNotes(note:getNotes())
		self.editorModel.visualEngine.selectedNotes[note.startNote] = note
	end
	self.editorModel.editorChanges:next()
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
	local note = EditorNoteFactory:newNote_t(noteType, self.editorModel.visualEngine.visual_info)
	note.editorModel = self.editorModel
	note.visualEngine = self.editorModel.visualEngine
	note.column = column
	return note:create(absoluteTime, column)
end

---@param absoluteTime number
---@param column string
function NoteManager:addNote(absoluteTime, column)
	local editorModel = self.editorModel
	editorModel.editorChanges:reset()
	local editor = editorModel:getSettings()
	editorModel.visualEngine:selectNote()

	local note
	if editor.tool == "ShortNote" then
		note = self:newNote("tap", absoluteTime, column)
	elseif editor.tool == "LongNote" then
		note = self:newNote("hold", absoluteTime, column)
	end

	if not note then
		return
	end
	self:_addNotes(note:getNotes(), note.column)

	editorModel.editorChanges:next()

	editorModel.visualEngine:selectNote(note)
	if editor.tool == "ShortNote" then
		self:grabNotes("head", editorModel:getMouseTime())
	elseif editor.tool == "LongNote" then
		self:grabNotes(
			"tail",
			editorModel:getMouseTime() +
			note.endNote:getTime() -
			note.startNote:getTime()
		)
	end
end

function NoteManager:flipNotes()
	local editorModel = self.editorModel
	local noteSkin = self.editorModel.session.noteSkin

	editorModel.editorChanges:reset()

	local notes = {}

	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		table.insert(notes, note)
		self:_removeNote(note)
	end

	for _, note in ipairs(notes) do
		local columns = noteSkin.columnsCount
		local column = columns - noteSkin:getInputColumn(note.column) + 1
		note:setColumn(noteSkin:getFirstColumnInput(column))
		self:_addNotes(note:getNotes())
	end

	editorModel.editorChanges:next()
end

return NoteManager
