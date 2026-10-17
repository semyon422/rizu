local class = require("class")
local EditorNoteFactory = require("rizu.editor.notes.EditorNoteFactory")

---@class rizu.editor.EditorNoteCreateServiceContext
---@field getVisualInfo fun(): rizu.VisualInfo
---@field getEditorNoteContext fun(): rizu.editor.EditorNoteContext
---@field getVisualEngine fun(): rizu.editor.VisualEngine
---@field getSettings fun(): table
---@field selectNote fun(note: rizu.editor.EditorNote?)
---@field getMouseTime fun(): number

---@class rizu.editor.EditorNoteCreateService
---@operator call: rizu.editor.EditorNoteCreateService
---@field context rizu.editor.EditorNoteCreateServiceContext
---@field dragService rizu.editor.EditorNoteDragService
local EditorNoteCreateService = class()

---@param dragService rizu.editor.EditorNoteDragService
function EditorNoteCreateService:new(dragService)
	self.dragService = dragService
end

---@param context rizu.editor.EditorNoteCreateServiceContext
function EditorNoteCreateService:setContext(context)
	self.context = context
end

---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote?
function EditorNoteCreateService:newNote(noteType, absoluteTime, column)
	local context = self.context
	local note = EditorNoteFactory:newNote_t(noteType, context:getVisualInfo())
	if not note then
		return
	end
	note:setContext(context:getEditorNoteContext())
	note.visualEngine = context:getVisualEngine()
	note.column = column
	return note:create(absoluteTime, column)
end

---@param absoluteTime number
---@param column string
---@param mouseTime number?
function EditorNoteCreateService:addNote(absoluteTime, column, mouseTime)
	local context = self.context
	local editor = context:getSettings()
	context:selectNote()
	mouseTime = mouseTime or context:getMouseTime()

	local note
	if editor.tool == "ShortNote" then
		note = self:newNote("tap", absoluteTime, column)
	elseif editor.tool == "LongNote" then
		note = self:newNote("hold", absoluteTime, column)
	end

	if not note then
		return
	end

	context:selectNote(note)
	if editor.tool == "ShortNote" then
		self.dragService:grabNew(note, "head", mouseTime)
	elseif editor.tool == "LongNote" then
		self.dragService:grabNew(
			note,
			"tail",
			mouseTime +
			note.endNote:getTime() -
			note.startNote:getTime()
		)
	end
end

return EditorNoteCreateService
