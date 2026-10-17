local class = require("class")
local EditorClipboardService = require("rizu.editor.notes.EditorClipboardService")
local EditorNoteColumnService = require("rizu.editor.notes.EditorNoteColumnService")
local EditorNoteCommandService = require("rizu.editor.notes.EditorNoteCommandService")
local EditorNoteCreateService = require("rizu.editor.notes.EditorNoteCreateService")
local EditorNoteDragService = require("rizu.editor.notes.EditorNoteDragService")

---@class rizu.editor.EditorNoteServiceContext: rizu.editor.EditorNoteColumnServiceContext, rizu.editor.EditorNoteCommandServiceContext, rizu.editor.EditorNoteDragServiceContext, rizu.editor.EditorClipboardServiceContext, rizu.editor.EditorNoteCreateServiceContext

---@class rizu.editor.EditorNoteServiceDeps
---@field columnService rizu.editor.EditorNoteColumnService?
---@field commandService rizu.editor.EditorNoteCommandService?
---@field dragService rizu.editor.EditorNoteDragService?
---@field clipboardService rizu.editor.EditorClipboardService?
---@field createService rizu.editor.EditorNoteCreateService?

---@class rizu.editor.EditorNoteService
---@operator call: rizu.editor.EditorNoteService
---@field context rizu.editor.EditorNoteServiceContext
---@field columnService rizu.editor.EditorNoteColumnService
---@field commandService rizu.editor.EditorNoteCommandService
---@field dragService rizu.editor.EditorNoteDragService
---@field clipboardService rizu.editor.EditorClipboardService
---@field createService rizu.editor.EditorNoteCreateService
local EditorNoteService = class()

---@param deps rizu.editor.EditorNoteServiceDeps?
function EditorNoteService:new(deps)
	deps = deps or {}
	local columnService = deps.columnService or EditorNoteColumnService()
	local commandService = deps.commandService or EditorNoteCommandService()
	local dragService = deps.dragService or EditorNoteDragService(commandService, columnService)

	self.columnService = columnService
	self.commandService = commandService
	self.dragService = dragService
	self.clipboardService = deps.clipboardService or EditorClipboardService(commandService)
	self.createService = deps.createService or EditorNoteCreateService(dragService)
end

---@param context rizu.editor.EditorNoteServiceContext
function EditorNoteService:setContext(context)
	self.context = context
	self.columnService:setContext(context)
	self.commandService:setContext(context)
	self.dragService:setContext(context)
	self.clipboardService:setContext(context)
	self.createService:setContext(context)
end

function EditorNoteService:update()
	self.dragService:update()
end

---@param cut boolean?
function EditorNoteService:copyNotes(cut)
	self.clipboardService:copy(cut)
end

---@return number
function EditorNoteService:deleteNotes()
	return self.commandService:deleteSelected()
end

function EditorNoteService:changeType()
	self.commandService:changeSelectedType()
end

function EditorNoteService:pasteNotes()
	self.clipboardService:paste()
end

---@param part string
---@param mouseTime number
function EditorNoteService:grabNotes(part, mouseTime)
	self.dragService:grab(part, mouseTime)
end

---@param mouseTime number
function EditorNoteService:dropNotes(mouseTime)
	self.dragService:drop(mouseTime)
end

---@param note rizu.editor.EditorNote
function EditorNoteService:removeNote(note)
	self.commandService:removeNote(note)
end

---@param absoluteTime number
---@param column string
---@param mouseTime number?
function EditorNoteService:addNote(absoluteTime, column, mouseTime)
	self.createService:addNote(absoluteTime, column, mouseTime)
end

function EditorNoteService:flipNotes()
	self.commandService:flipSelected()
end

---@return rizu.editor.EditorNote[]
function EditorNoteService:getGrabbedNotes()
	return self.dragService:getGrabbedNotes()
end

---@return rizu.editor.EditorNote[]
function EditorNoteService:getCopiedNotes()
	return self.clipboardService:getCopiedNotes()
end

---@param column integer?
function EditorNoteService:setColumnOver(column)
	self.columnService:setColumnOver(column)
end

return EditorNoteService
