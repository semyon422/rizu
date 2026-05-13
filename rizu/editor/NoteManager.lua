local class = require("class")
local Fraction = require("ncdk.Fraction")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")
local ShortEditorNote = require("rizu.editor.ShortEditorNote")
local LongEditorNote = require("rizu.editor.LongEditorNote")
local Note = require("ncdk2.notes.Note")

---@class rizu.editor.EditorNoteManager
---@operator call: rizu.editor.EditorNoteManager
local NoteManager = class()

function NoteManager:new()
	self.grabbedNotes = {}
end

---@return number
function NoteManager:getColumnOver()
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local noteSkin = self.editorModel.noteSkin
	return noteSkin:getInverseColumnPosition(mx)
end

function NoteManager:update()
	local editor = self.editorModel:getSettings()
	local noteSkin = self.editorModel.noteSkin

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

	for _, note in pairs(self.editorModel.graphicEngine.selectedNotes) do
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

	for n, note in pairs(self.editorModel.graphicEngine.selectedNotes) do
		self:_removeNote(note)
		c = c + 1
	end
	self.editorModel.editorChanges:next()
	return c
end

function NoteManager:changeType()
	---@type rizu.editor.EditorModel
	local editorModel = self.editorModel
	local layer = editorModel.layer
	local visual = editorModel.visual
	local editor = editorModel:getSettings()

	-- self.editorModel.editorChanges:reset()

	for _, note in pairs(editorModel.graphicEngine.selectedNotes) do
		note:remove()
		if not note.endNote then
			local startNote = note.startNote
			startNote.type = "hold"
			startNote.weight = 1

			local p = startNote.visualPoint.point
			local p_end = layer.points:getPoint(p:add(Fraction(1, editor.snap)))
			local vp_end = visual:getPoint(p_end)
			local endNote = Note(vp_end, note.column, "hold", -1)
			editorModel.notes:addNote(endNote)

			note.endNote = endNote

			endNote.startNote = startNote
			startNote.endNote = endNote

			setmetatable(note, LongEditorNote)
		else
			local startNote = note.startNote
			startNote.type = "tap"
			startNote.weight = 0
			startNote.endNote = nil
			note.endNote.type = "ignore"
			note.endNote.weight = 0
			note.endNote.startNote = nil
			note.endNote = nil

			setmetatable(note, ShortEditorNote)
		end
		note:add()
	end

	self.editorModel.graphicEngine:reset()

	-- self.editorModel.editorChanges:next()
end

function NoteManager:pasteNotes()
	local copiedNotes = self.copiedNotes
	if not copiedNotes then
		return
	end

	self.editorModel.editorChanges:reset()
	local point = self.editorModel.point
	for _, note in ipairs(copiedNotes) do
		self:_addNotes(note:paste(point))
	end
	self.editorModel.editorChanges:next()
end

---@param part string
---@param mouseTime number
function NoteManager:grabNotes(part, mouseTime)
	local noteSkin = self.editorModel.noteSkin
	local editor = self.editorModel:getSettings()

	self.grabbedNotes = {}
	self.editorModel.editorChanges:reset()
	local column = self:getColumnOver()
	for _, note in pairs(self.editorModel.graphicEngine.selectedNotes) do
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
		self.editorModel.graphicEngine.selectedNotes[note.startNote] = note
	end
	self.editorModel.editorChanges:next()
end

---@param note rizu.editor.EditorNote
function NoteManager:_removeNote(note)
	self.editorModel.graphicEngine.selectedNotes[note.startNote] = nil
	local lnotes = self.editorModel.notes
	local notes = note:getNotes()
	for _, _note in ipairs(notes) do
		lnotes:removeNote(_note)
		self.editorModel.editorChanges:add(
			{lnotes, "removeNote", lnotes, _note},
			{lnotes, "addNote", lnotes, _note}
		)
	end
end

---@param note rizu.editor.EditorNote
function NoteManager:removeNote(note)
	self.editorModel.editorChanges:reset()
	self:_removeNote(note)
	self.editorModel.editorChanges:next()
end

---@param notes ncdk2.Note[]
function NoteManager:_addNotes(notes)
	local lnotes = self.editorModel.notes
	local found = false
	for _, _note in ipairs(notes) do
		found = found or lnotes:findNote(_note)
	end
	if found then
		return
	end

	for _, _note in ipairs(notes) do
		lnotes:addNote(_note)
		self.editorModel.editorChanges:add(
			{lnotes, "addNote", lnotes, _note},
			{lnotes, "removeNote", lnotes, _note}
		)
	end
end

---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote?
function NoteManager:newNote(noteType, absoluteTime, column)
	local note = EditorNoteFactory:newNote_t(noteType)
	note.editorModel = self.editorModel
	note.graphicEngine = self.editorModel.graphicEngine
	note.column = column
	return note:create(absoluteTime, column)
end

---@param absoluteTime number
---@param column string
function NoteManager:addNote(absoluteTime, column)
	local editorModel = self.editorModel
	editorModel.editorChanges:reset()
	local editor = editorModel:getSettings()
	editorModel.graphicEngine:selectNote()

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

	editorModel.graphicEngine:selectNote(note)
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
	local noteSkin = self.editorModel.noteSkin

	editorModel.editorChanges:reset()

	local notes = {}

	for _, note in pairs(editorModel.graphicEngine.selectedNotes) do
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
