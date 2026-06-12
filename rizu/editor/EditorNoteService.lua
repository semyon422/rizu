local class = require("class")
local EditorClipboardService = require("rizu.editor.EditorClipboardService")
local EditorNoteColumnService = require("rizu.editor.EditorNoteColumnService")
local EditorNoteCommandService = require("rizu.editor.EditorNoteCommandService")
local EditorNoteCreateService = require("rizu.editor.EditorNoteCreateService")
local EditorNoteDragService = require("rizu.editor.EditorNoteDragService")

---@class rizu.editor.EditorNoteServiceContext
---@field columnService rizu.editor.EditorNoteColumnServiceContext
---@field commandService rizu.editor.EditorNoteCommandServiceContext
---@field dragService rizu.editor.EditorNoteDragServiceContext
---@field clipboardService rizu.editor.EditorClipboardServiceContext
---@field createService rizu.editor.EditorNoteCreateServiceContext

---@class rizu.editor.EditorNoteService
---@operator call: rizu.editor.EditorNoteService
---@field context rizu.editor.EditorNoteServiceContext
local EditorNoteService = class()

function EditorNoteService:new()
	self.columnService = EditorNoteColumnService()
	self.commandService = EditorNoteCommandService()
	self.dragService = EditorNoteDragService(self.commandService, self.columnService)
	self.clipboardService = EditorClipboardService(self.commandService)
	self.createService = EditorNoteCreateService(self.dragService)
end

---@param context rizu.editor.EditorNoteServiceContext
function EditorNoteService:setContext(context)
	self.context = context
	self.columnService:setContext(context.columnService)
	self.commandService:setContext(context.commandService)
	self.dragService:setContext(context.dragService)
	self.clipboardService:setContext(context.clipboardService)
	self.createService:setContext(context.createService)
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
function EditorNoteService:addNote(absoluteTime, column)
	self.createService:addNote(absoluteTime, column)
end

function EditorNoteService:flipNotes()
	self.commandService:flipSelected()
end

---@return rizu.editor.EditorNote[]
function EditorNoteService:getGrabbedNotes()
	return self.dragService.grabbedNotes
end

---@return rizu.editor.EditorNote[]
function EditorNoteService:getCopiedNotes()
	return self.clipboardService.copiedNotes or {}
end

return EditorNoteService
