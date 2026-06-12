local class = require("class")

---@class rizu.editor.EditorNoteDragService
---@operator call: rizu.editor.EditorNoteDragService
---@field editorModel rizu.editor.EditorModel
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

---@param editorModel rizu.editor.EditorModel
function EditorNoteDragService:setEditorModel(editorModel)
	self.editorModel = editorModel
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
	local editorModel = self.editorModel
	local noteSkin = assert(editorModel:getNoteSkin())
	local editor = editorModel:getSettings()

	self:clear()
	editorModel.editorChanges:reset()
	local column = self.columnService:getColumnOver()
	local deltaColumn = getColumnDelta(noteSkin, column, note)
	if not deltaColumn then
		return
	end

	table.insert(self.grabbedNotes, note)
	note:grab(mouseTime, part, deltaColumn, editor.lockSnap)
	editorModel.visualEngine.selectedNotes[note.startNote] = note
end

function EditorNoteDragService:update()
	local editorModel = self.editorModel
	local editor = editorModel:getSettings()
	local noteSkin = assert(editorModel:getNoteSkin())

	for _, note in ipairs(self.grabbedNotes) do
		note:update()
		local time = editorModel:getMouseTime()
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
	local editorModel = self.editorModel
	local noteSkin = assert(editorModel:getNoteSkin())
	local editor = editorModel:getSettings()

	self:clear()
	editorModel.editorChanges:reset()
	local column = self.columnService:getColumnOver()
	for _, note in ipairs(getSelectedNotes(editorModel.visualEngine.selectedNotes)) do
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
	local editorModel = self.editorModel
	local editor = editorModel:getSettings()

	for _, note in ipairs(self.grabbedNotes) do
		if not editor.lockSnap then
			note:drop(mouseTime)
		end
		self.commandService:addNotes(note:getNotes())
		editorModel.visualEngine.selectedNotes[note.startNote] = note
	end
	self:clear()
	editorModel.editorChanges:next()
end

return EditorNoteDragService
