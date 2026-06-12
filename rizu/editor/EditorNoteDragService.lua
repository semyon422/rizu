local class = require("class")

---@class rizu.editor.EditorNoteDragServiceContext
---@field getNoteSkin fun(): table?
---@field getSettings fun(): table
---@field editorChanges rizu.editor.EditorChanges
---@field getSelectedNotes fun(): {[chart.Note]: rizu.editor.EditorNote}
---@field getMouseTime fun(): number

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

---@param note rizu.editor.EditorNote
---@param part string
---@param mouseTime number
function EditorNoteDragService:grabNew(note, part, mouseTime)
	local context = self.context
	local noteSkin = assert(context.getNoteSkin())
	local editor = context.getSettings()

	self:clear()
	context.editorChanges:reset()
	local column = self.columnService:getColumnOver()
	local deltaColumn = getColumnDelta(noteSkin, column, note)
	if not deltaColumn then
		return
	end

	table.insert(self.grabbedNotes, note)
	note:grab(mouseTime, part, deltaColumn, editor.lockSnap)
	context.getSelectedNotes()[note.startNote] = note
end

function EditorNoteDragService:update()
	local context = self.context
	local editor = context.getSettings()
	local noteSkin = assert(context.getNoteSkin())

	for _, note in ipairs(self.grabbedNotes) do
		note:update()
		local time = context.getMouseTime()
		if not editor.lockSnap then
			note:updateGrabbed(time)
		end
		local column = self.columnService:getColumnOver()
		if column then
			column = column - note.grabbedDeltaColumn
			note:setColumn(noteSkin:getFirstColumnInput(column))
		end
	end
end

---@param part string
---@param mouseTime number
function EditorNoteDragService:grab(part, mouseTime)
	local context = self.context
	local noteSkin = assert(context.getNoteSkin())
	local editor = context.getSettings()

	self:clear()
	context.editorChanges:reset()
	local column = self.columnService:getColumnOver()
	for _, note in ipairs(getSelectedNotes(context.getSelectedNotes())) do
		local deltaColumn = getColumnDelta(noteSkin, column, note)
		if deltaColumn then
			table.insert(self.grabbedNotes, note)
			self.commandService:removeNoteWithoutUndoBoundary(note)
			note:grab(mouseTime, part, deltaColumn, editor.lockSnap)
		end
	end
end

---@param mouseTime number
function EditorNoteDragService:drop(mouseTime)
	local context = self.context
	local editor = context.getSettings()

	for _, note in ipairs(self.grabbedNotes) do
		if not editor.lockSnap then
			note:drop(mouseTime)
		end
		self.commandService:addNotes(note:getNotes())
		context.getSelectedNotes()[note.startNote] = note
	end
	self:clear()
	context.editorChanges:next()
end

return EditorNoteDragService
