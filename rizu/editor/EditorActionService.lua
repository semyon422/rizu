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
	local noteManager = editorModel.noteManager
	local notificationModel = context.notificationModel
	local keypressed = context.keypressed

	if editorModel.isEditorCommandRequested() then
		if keypressed("s") then
			editorController:save()
			notificationModel:notify("saved")
		elseif keypressed("c") then
			noteManager:copyNotes()
			notificationModel:notify("copy " .. #noteManager.copiedNotes .. " notes")
		elseif keypressed("x") then
			noteManager:copyNotes(true)
			notificationModel:notify("cut " .. #noteManager.copiedNotes .. " notes")
		elseif keypressed("v") then
			noteManager:pasteNotes()
			notificationModel:notify("paste " .. #noteManager.copiedNotes .. " notes")
		elseif keypressed("h") then
			noteManager:flipNotes()
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
		local deleted = noteManager:deleteNotes()
		notificationModel:notify("delete " .. deleted .. " notes")
	end
end

return EditorActionService
