local class = require("class")

---@class rizu.editor.EditorActionService
---@operator call: rizu.editor.EditorActionService
local EditorActionService = class()

---@alias rizu.editor.KeyPressedFunc fun(key: string): boolean

---@class rizu.editor.EditorActionContext
---@field editorController rizu.editor.EditorController
---@field editorModel rizu.editor.EditorModel
---@field notificationModel table
---@field keypressed rizu.editor.KeyPressedFunc

---@param context rizu.editor.EditorActionContext
function EditorActionService:handleHotkeys(context)
	local editorController = context.editorController
	local editorModel = context.editorModel
	local noteService = editorModel.noteService
	local notificationModel = context.notificationModel
	local keypressed = context.keypressed

	if editorModel.isEditorCommandRequested() then
		if keypressed("s") then
			editorController:save()
			notificationModel:notify("saved")
		elseif keypressed("c") then
			noteService:copyNotes()
			notificationModel:notify("copy " .. #noteService:getCopiedNotes() .. " notes")
		elseif keypressed("x") then
			noteService:copyNotes(true)
			notificationModel:notify("cut " .. #noteService:getCopiedNotes() .. " notes")
		elseif keypressed("v") then
			noteService:pasteNotes()
			notificationModel:notify("paste " .. #noteService:getCopiedNotes() .. " notes")
		elseif keypressed("h") then
			noteService:flipNotes()
			notificationModel:notify("flip")
		elseif keypressed("z") then
			editorModel:undo()
			notificationModel:notify("undo")
		elseif keypressed("y") then
			editorModel:redo()
			notificationModel:notify("redo")
		end
	end

	if keypressed("delete") then
		local deleted = noteService:deleteNotes()
		notificationModel:notify("delete " .. deleted .. " notes")
	end
end

return EditorActionService
