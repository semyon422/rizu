local class = require("class")

---@class rizu.editor.EditorNoteDragServiceContext
---@field getNoteSkin fun(): table?
---@field getSettings fun(): table
---@field getSelectedNotes fun(): {[chart.Note]: rizu.editor.EditorNote}
---@field getMouseTime fun(): number
---@field getEditorChanges fun(): rizu.editor.EditorChanges

---@class rizu.editor.EditorNoteDragService
---@operator call: rizu.editor.EditorNoteDragService
---@field context rizu.editor.EditorNoteDragServiceContext
---@field commandService rizu.editor.EditorNoteCommandService
---@field columnService rizu.editor.EditorNoteColumnService
---@field grabbedNotes rizu.editor.EditorNote[]
local EditorNoteDragService = class()

---@param commandService rizu.editor.EditorNoteCommandService
---@param columnService rizu.editor.EditorNoteColumnService
function EditorNoteDragService:new(commandService, columnService)
	self.commandService = commandService
	self.columnService = columnService
	self.grabbedNotes = {}
end

---@param context rizu.editor.EditorNoteDragServiceContext
function EditorNoteDragService:setContext(context)
	self.context = context
end

function EditorNoteDragService:clear()
	for i = #self.grabbedNotes, 1, -1 do
		self.grabbedNotes[i] = nil
	end
end

function EditorNoteDragService:beginDrag()
	self:clear()
	self.context:getEditorChanges():reset()
end

---@param noteSkin table
---@param column integer?
---@param note rizu.editor.EditorNote
---@return number?
local function getColumnDelta(noteSkin, column, note)
	if not column then
		return
	end
	local noteColumn = noteSkin:getInputColumn(note.column)
	if not noteColumn then
		return
	end
	return column - noteColumn
end

---@return number?
function EditorNoteDragService:getColumnOver()
	return self.columnService:getColumnOver()
end

---@param noteSkin table
---@param note rizu.editor.EditorNote
---@return number?
function EditorNoteDragService:getGrabDeltaColumn(noteSkin, note)
	return getColumnDelta(noteSkin, self:getColumnOver(), note)
end

---@param selectedNotes {[chart.Note]: rizu.editor.EditorNote}
---@return rizu.editor.EditorNote[]
local function getSelectedNotes(selectedNotes)
	---@type rizu.editor.EditorNote[]
	local notes = {}
	for _, note in pairs(selectedNotes) do
		table.insert(notes, note)
	end
	return notes
end

---@return rizu.editor.EditorNote[]
function EditorNoteDragService:getSelectedNotes()
	return getSelectedNotes(self.context:getSelectedNotes())
end

---@param note rizu.editor.EditorNote
function EditorNoteDragService:addGrabbedNote(note)
	table.insert(self.grabbedNotes, note)
end

---@param note rizu.editor.EditorNote
function EditorNoteDragService:selectGrabbedNote(note)
	self.context:getSelectedNotes()[note.startNote] = note
end

---@param noteSkin table
---@param note rizu.editor.EditorNote
---@param part string
---@param mouseTime number
---@param removeBeforeGrab boolean
---@return boolean grabbed
function EditorNoteDragService:grabNote(noteSkin, note, part, mouseTime, removeBeforeGrab)
	local deltaColumn = self:getGrabDeltaColumn(noteSkin, note)
	if not deltaColumn then
		return false
	end

	if removeBeforeGrab then
		self.commandService:removeNoteWithoutUndoBoundary(note)
	end

	local editor = self.context:getSettings()
	self:addGrabbedNote(note)
	note:grab(mouseTime, part, deltaColumn, editor.lockSnap)
	return true
end

---@param note rizu.editor.EditorNote
---@param part string
---@param mouseTime number
function EditorNoteDragService:grabNew(note, part, mouseTime)
	local context = self.context
	local noteSkin = assert(context:getNoteSkin())

	self:beginDrag()
	if not self:grabNote(noteSkin, note, part, mouseTime, false) then
		return
	end

	self:selectGrabbedNote(note)
end

---@param noteSkin table
---@param note rizu.editor.EditorNote
function EditorNoteDragService:updateNoteColumn(noteSkin, note)
	local column = self:getColumnOver()
	if not column then
		return
	end

	column = column - note.grabbedDeltaColumn
	note:setColumn(noteSkin:getFirstColumnInput(column))
end

---@param editor table
---@param note rizu.editor.EditorNote
function EditorNoteDragService:updateGrabbedNote(editor, note)
	note:update()
	if not editor.lockSnap then
		note:updateGrabbed(self.context:getMouseTime())
	end
end

function EditorNoteDragService:update()
	local context = self.context
	local editor = context:getSettings()
	local noteSkin = assert(context:getNoteSkin())

	for _, note in ipairs(self.grabbedNotes) do
		self:updateGrabbedNote(editor, note)
		self:updateNoteColumn(noteSkin, note)
	end
end

---@param part string
---@param mouseTime number
function EditorNoteDragService:grab(part, mouseTime)
	local context = self.context
	local noteSkin = assert(context:getNoteSkin())

	self:beginDrag()
	for _, note in ipairs(self:getSelectedNotes()) do
		self:grabNote(noteSkin, note, part, mouseTime, true)
	end
end

---@param editor table
---@param note rizu.editor.EditorNote
---@param mouseTime number
function EditorNoteDragService:dropNote(editor, note, mouseTime)
	if not editor.lockSnap then
		note:drop(mouseTime)
	end
	self.commandService:addNotes(note:getNotes())
	self:selectGrabbedNote(note)
end

---@param mouseTime number
function EditorNoteDragService:drop(mouseTime)
	local context = self.context
	local editor = context:getSettings()

	for _, note in ipairs(self.grabbedNotes) do
		self:dropNote(editor, note, mouseTime)
	end
	self:clear()
	context:getEditorChanges():next()
end

return EditorNoteDragService
