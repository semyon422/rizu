local class = require("class")

---@class rizu.editor.EditorActionService
---@operator call: rizu.editor.EditorActionService
local EditorActionService = class()

---@alias rizu.editor.KeyPressedFunc fun(key: string): boolean

---@class rizu.editor.EditorActionContext
---@field editorController rizu.editor.EditorController
---@field editorModel rizu.editor.EditorModel
---@field notificationModel {notify: fun(self: table, message: string)}
---@field keypressed rizu.editor.KeyPressedFunc

---@param context rizu.editor.EditorActionContext
function EditorActionService:save(context)
	context.editorController:save()
	context.notificationModel:notify("saved")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:copy(context)
	local noteService = context.editorModel.noteService
	noteService:copyNotes()
	context.notificationModel:notify("copy " .. #noteService:getCopiedNotes() .. " notes")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:cut(context)
	local noteService = context.editorModel.noteService
	noteService:copyNotes(true)
	context.notificationModel:notify("cut " .. #noteService:getCopiedNotes() .. " notes")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:paste(context)
	local noteService = context.editorModel.noteService
	noteService:pasteNotes()
	context.notificationModel:notify("paste " .. #noteService:getCopiedNotes() .. " notes")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:flip(context)
	context.editorModel.noteService:flipNotes()
	context.notificationModel:notify("flip")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:undo(context)
	context.editorModel:undo()
	context.notificationModel:notify("undo")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:redo(context)
	context.editorModel:redo()
	context.notificationModel:notify("redo")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:delete(context)
	local deleted = context.editorModel.noteService:deleteNotes()
	context.notificationModel:notify("delete " .. deleted .. " notes")
end

---@param context rizu.editor.EditorActionContext
---@return boolean handled
function EditorActionService:handleCommandHotkey(context)
	local keypressed = context.keypressed
	if keypressed("s") then
		self:save(context)
	elseif keypressed("c") then
		self:copy(context)
	elseif keypressed("x") then
		self:cut(context)
	elseif keypressed("v") then
		self:paste(context)
	elseif keypressed("h") then
		self:flip(context)
	elseif keypressed("z") then
		self:undo(context)
	elseif keypressed("y") then
		self:redo(context)
	else
		return false
	end
	return true
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:handleHotkeys(context)
	local editorModel = context.editorModel
	local keypressed = context.keypressed

	if editorModel.isEditorCommandRequested() then
		self:handleCommandHotkey(context)
	end

	if keypressed("delete") then
		self:delete(context)
	end
end

return EditorActionService
