local class = require("class")

---@class rizu.editor.EditorActionService
---@operator call: rizu.editor.EditorActionService
local EditorActionService = class()

---@alias rizu.editor.KeyPressedFunc fun(key: string): boolean

---@class rizu.editor.EditorActionContext
---@field save fun(self: rizu.editor.EditorActionContext)
---@field copyNotes fun(self: rizu.editor.EditorActionContext, cut: boolean?)
---@field pasteNotes fun(self: rizu.editor.EditorActionContext)
---@field flipNotes fun(self: rizu.editor.EditorActionContext)
---@field undo fun(self: rizu.editor.EditorActionContext)
---@field redo fun(self: rizu.editor.EditorActionContext)
---@field deleteNotes fun(self: rizu.editor.EditorActionContext): integer
---@field getCopiedNoteCount fun(self: rizu.editor.EditorActionContext): integer
---@field notify fun(self: rizu.editor.EditorActionContext, message: string)
---@field isEditorCommandRequested fun(self: rizu.editor.EditorActionContext): boolean
---@field keypressed rizu.editor.KeyPressedFunc

---@param context rizu.editor.EditorActionContext
function EditorActionService:save(context)
	context:save()
	context:notify("saved")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:copy(context)
	context:copyNotes()
	context:notify("copy " .. context:getCopiedNoteCount() .. " notes")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:cut(context)
	context:copyNotes(true)
	context:notify("cut " .. context:getCopiedNoteCount() .. " notes")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:paste(context)
	context:pasteNotes()
	context:notify("paste " .. context:getCopiedNoteCount() .. " notes")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:flip(context)
	context:flipNotes()
	context:notify("flip")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:undo(context)
	context:undo()
	context:notify("undo")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:redo(context)
	context:redo()
	context:notify("redo")
end

---@param context rizu.editor.EditorActionContext
function EditorActionService:delete(context)
	local deleted = context:deleteNotes()
	context:notify("delete " .. deleted .. " notes")
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
	local keypressed = context.keypressed

	if context:isEditorCommandRequested() then
		self:handleCommandHotkey(context)
	end

	if keypressed("delete") then
		self:delete(context)
	end
end

return EditorActionService
