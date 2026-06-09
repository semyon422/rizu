local class = require("class")

---@class rizu.editor.NoteDragSession
---@operator call: rizu.editor.NoteDragSession
---@field noteManager rizu.editor.NoteManager
---@field grabbedNotes rizu.editor.EditorNote[]
local NoteDragSession = class()

---@param noteManager rizu.editor.NoteManager
function NoteDragSession:new(noteManager)
	self.noteManager = noteManager
	self.grabbedNotes = {}
end

function NoteDragSession:clear()
	for i = #self.grabbedNotes, 1, -1 do
		self.grabbedNotes[i] = nil
	end
end

---@param note rizu.editor.EditorNote
---@param part string
---@param mouseTime number
function NoteDragSession:grabNew(note, part, mouseTime)
	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel
	local noteSkin = editorModel.session.noteSkin
	local editor = editorModel:getSettings()

	self:clear()
	editorModel.editorChanges:reset()
	local column = noteManager:getColumnOver()
	local noteColumn = noteSkin:getInputColumn(note.column)
	if not noteColumn then
		return
	end

	table.insert(self.grabbedNotes, note)
	note:grab(mouseTime, part, column - noteColumn, editor.lockSnap)
	editorModel.visualEngine.selectedNotes[note.startNote] = note
end

function NoteDragSession:update()
	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel
	local editor = editorModel:getSettings()
	local noteSkin = editorModel.session.noteSkin

	for _, note in ipairs(self.grabbedNotes) do
		note:update()
		local time = editorModel:getMouseTime()
		if not editor.lockSnap then
			note:updateGrabbed(time)
		end
		local column = noteManager:getColumnOver()
		if column then
			column = column - note.grabbedDeltaColumn
			note:setColumn(noteSkin:getFirstColumnInput(column))
		end
	end
end

---@param part string
---@param mouseTime number
function NoteDragSession:grab(part, mouseTime)
	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel
	local noteSkin = editorModel.session.noteSkin
	local editor = editorModel:getSettings()

	self:clear()
	editorModel.editorChanges:reset()
	local column = noteManager:getColumnOver()
	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		local noteColumn = noteSkin:getInputColumn(note.column)
		if noteColumn then
			table.insert(self.grabbedNotes, note)
			noteManager:_removeNote(note)
			note:grab(mouseTime, part, column - noteColumn, editor.lockSnap)
		end
	end
end

---@param mouseTime number
function NoteDragSession:drop(mouseTime)
	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel
	local editor = editorModel:getSettings()

	for _, note in ipairs(self.grabbedNotes) do
		if not editor.lockSnap then
			note:drop(mouseTime)
		end
		noteManager:_addNotes(note:getNotes())
		editorModel.visualEngine.selectedNotes[note.startNote] = note
	end
	self:clear()
	editorModel.editorChanges:next()
end

return NoteDragSession
