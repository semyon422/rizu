local class = require("class")
local EditorPlayfieldService = require("rizu.editor.view.playfield.EditorPlayfieldService")

---@class rizu.editor.EditorPlayfieldInputServiceDeps
---@field playfieldService rizu.editor.EditorPlayfieldService?

---@class rizu.editor.EditorPlayfieldInputState
---@field leftPressed boolean
---@field rightPressed boolean
---@field leftReleased boolean

---@class rizu.editor.EditorPlayfieldNoteInput
---@field note rizu.editor.EditorNote
---@field mouseTime number
---@field leftPressed boolean?
---@field rightPressed boolean?
---@field bodyOver boolean?
---@field headOver boolean?
---@field tailOver boolean?

---@class rizu.editor.EditorPlayfieldColumnInput
---@field columnIndex integer
---@field time number
---@field mouseTime number?
---@field over boolean?
---@field leftPressed boolean?

---@class rizu.editor.EditorPlayfieldSelectInput
---@field mx number?
---@field my number?
---@field mouseTime number?
---@field over boolean?
---@field leftPressed boolean?

---@class rizu.editor.EditorPlayfieldReleaseInput
---@field leftReleased boolean?
---@field mouseTime number

---@class rizu.editor.EditorPlayfieldInputService
---@operator call: rizu.editor.EditorPlayfieldInputService
---@field playfieldService rizu.editor.EditorPlayfieldService
local EditorPlayfieldInputService = class()

---@param deps rizu.editor.EditorPlayfieldInputServiceDeps?
function EditorPlayfieldInputService:new(deps)
	deps = deps or {}
	self.playfieldService = deps.playfieldService or EditorPlayfieldService()
end

---@param context rizu.editor.EditorPlayfieldContext
---@param input rizu.editor.EditorPlayfieldNoteInput
---@return boolean handled
function EditorPlayfieldInputService:handleNoteInput(context, input)
	if not self.playfieldService:isNotesActive(context) then
		return false
	end

	local part
	if input.bodyOver then
		part = "body"
	elseif input.headOver then
		part = "head"
	elseif input.tailOver then
		part = "tail"
	end

	if not part then
		return false
	end

	if input.leftPressed then
		self.playfieldService:selectNoteAndGrab(context, input.note, part, input.mouseTime)
		return true
	end

	if input.rightPressed then
		self.playfieldService:removeNote(context, input.note)
		return true
	end

	return false
end

---@param context rizu.editor.EditorPlayfieldContext
---@param input rizu.editor.EditorPlayfieldColumnInput
---@return boolean handled
function EditorPlayfieldInputService:handleColumnInput(context, input)
	if not self.playfieldService:isNotesActive(context) then
		return false
	end

	if not input.over or not input.leftPressed then
		return false
	end

	self.playfieldService:addNote(context, input.time, input.columnIndex, input.mouseTime)
	return true
end

---@param context rizu.editor.EditorPlayfieldContext
---@param input rizu.editor.EditorPlayfieldSelectInput
---@return boolean handled
function EditorPlayfieldInputService:handleSelectInput(context, input)
	if not self.playfieldService:isNotesActive(context) then
		return false
	end

	if not input.over or not input.leftPressed then
		return false
	end

	self.playfieldService:selectStart(context, input.mx, input.my, input.mouseTime)
	return true
end

---@param context rizu.editor.EditorPlayfieldContext
---@param input rizu.editor.EditorPlayfieldReleaseInput
---@return boolean handled
function EditorPlayfieldInputService:handleReleaseInput(context, input)
	if not self.playfieldService:isNotesActive(context) then
		return false
	end

	if not input.leftReleased then
		return false
	end

	local dropped = self.playfieldService:dropGrabbedNotes(context, input.mouseTime)
	local selected = self.playfieldService:selectEndIfSelecting(context)
	return dropped or selected
end

return EditorPlayfieldInputService
