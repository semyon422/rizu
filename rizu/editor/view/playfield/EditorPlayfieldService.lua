local class = require("class")

---@class rizu.editor.EditorPlayfieldContext
---@field getSelectionState fun(self: rizu.editor.EditorPlayfieldContext): rizu.editor.EditorSelectionState
---@field getViewState fun(self: rizu.editor.EditorPlayfieldContext): rizu.editor.EditorViewState
---@field getEditorSettings fun(self: rizu.editor.EditorPlayfieldContext): table
---@field getNoteService fun(self: rizu.editor.EditorPlayfieldContext): rizu.editor.EditorNoteService
---@field getVisualEngine fun(self: rizu.editor.EditorPlayfieldContext): rizu.editor.VisualEngine
---@field selectNote fun(self: rizu.editor.EditorPlayfieldContext, note: rizu.editor.EditorNote)
---@field selectStart fun(self: rizu.editor.EditorPlayfieldContext)
---@field selectStartAt fun(self: rizu.editor.EditorPlayfieldContext, mx: number, my: number, mouseTime: number)
---@field selectEnd fun(self: rizu.editor.EditorPlayfieldContext)

---@class rizu.editor.EditorPlayfieldService
---@operator call: rizu.editor.EditorPlayfieldService
local EditorPlayfieldService = class()

---@param context rizu.editor.EditorPlayfieldContext
---@return boolean
function EditorPlayfieldService:isNotesActive(context)
	return context:getViewState():getOverlayState() == "notes"
end

---@param context rizu.editor.EditorPlayfieldContext
---@return number[]?
function EditorPlayfieldService:getSelectionRect(context)
	return context:getSelectionState():getRect()
end

---@param context rizu.editor.EditorPlayfieldContext
---@return boolean
function EditorPlayfieldService:canAddNote(context)
	if not self:isNotesActive(context) then
		return false
	end
	local tool = context:getEditorSettings().tool
	return tool == "ShortNote" or tool == "LongNote"
end

---@param context rizu.editor.EditorPlayfieldContext
---@return boolean
function EditorPlayfieldService:isSelectTool(context)
	if not self:isNotesActive(context) then
		return false
	end
	return context:getEditorSettings().tool == "Select"
end

---@param context rizu.editor.EditorPlayfieldContext
---@param time number
---@param columnIndex integer
---@param mouseTime number?
function EditorPlayfieldService:addNote(context, time, columnIndex, mouseTime)
	context:getNoteService():addNote(time, "key" .. columnIndex, mouseTime)
end

---@param context rizu.editor.EditorPlayfieldContext
---@param mx number?
---@param my number?
---@param mouseTime number?
function EditorPlayfieldService:selectStart(context, mx, my, mouseTime)
	if mx and my and mouseTime then
		context:selectStartAt(mx, my, mouseTime)
	else
		context:selectStart()
	end
end

---@param context rizu.editor.EditorPlayfieldContext
---@param note rizu.editor.EditorNote
---@param part "body"|"head"|"tail"
---@param mouseTime number
function EditorPlayfieldService:selectNoteAndGrab(context, note, part, mouseTime)
	context:selectNote(note)
	context:getNoteService():grabNotes(part, mouseTime)
end

---@param context rizu.editor.EditorPlayfieldContext
---@param note rizu.editor.EditorNote
function EditorPlayfieldService:removeNote(context, note)
	context:getNoteService():removeNote(note)
end

---@param context rizu.editor.EditorPlayfieldContext
---@param mouseTime number
---@return boolean dropped
function EditorPlayfieldService:dropGrabbedNotes(context, mouseTime)
	if not next(context:getNoteService():getGrabbedNotes()) then
		return false
	end

	context:getNoteService():dropNotes(mouseTime)
	return true
end

---@param context rizu.editor.EditorPlayfieldContext
---@return boolean ended
function EditorPlayfieldService:selectEndIfSelecting(context)
	if not self:getSelectionRect(context) then
		return false
	end

	context:selectEnd()
	return true
end

return EditorPlayfieldService
