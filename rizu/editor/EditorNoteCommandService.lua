local class = require("class")
local EditorNoteOps = require("rizu.editor.EditorNoteOps")

---@class rizu.editor.EditorNoteCommandServiceContext
---@field getSelectedNotes fun(): {[chart.Note]: rizu.editor.EditorNote}
---@field getSettings fun(): table
---@field getNoteSkin fun(): table?
---@field resetVisual fun()
---@field getNoteOpsContext fun(): rizu.editor.EditorNoteOpsContext
---@field getEditorChanges fun(): rizu.editor.EditorChanges

---@class rizu.editor.EditorNoteCommandService
---@operator call: rizu.editor.EditorNoteCommandService
---@field context rizu.editor.EditorNoteCommandServiceContext
---@field noteOps rizu.editor.EditorNoteOps
local EditorNoteCommandService = class()

function EditorNoteCommandService:new()
	self.noteOps = EditorNoteOps()
end

---@param context rizu.editor.EditorNoteCommandServiceContext
function EditorNoteCommandService:setContext(context)
	self.context = context
end

---@return rizu.editor.EditorNoteOps
function EditorNoteCommandService:getNoteOps()
	self.noteOps:setContext(self.context:getNoteOpsContext())
	return self.noteOps
end

---@param notes chart.Note[]
---@return boolean added
function EditorNoteCommandService:addNotes(notes)
	return self:getNoteOps():addNotes(notes)
end

---@param note rizu.editor.EditorNote
function EditorNoteCommandService:removeNoteWithoutUndoBoundary(note)
	self.context:getSelectedNotes()[note.startNote] = nil
	self:getNoteOps():removeNotes(note:getNotes())
end

---@param note rizu.editor.EditorNote
function EditorNoteCommandService:removeNote(note)
	local editorChanges = self.context:getEditorChanges()
	editorChanges:reset()
	self:removeNoteWithoutUndoBoundary(note)
	editorChanges:next()
end

---@return number deleted
function EditorNoteCommandService:deleteSelected()
	return self:getNoteOps():deleteSelected(self.context:getSelectedNotes())
end

function EditorNoteCommandService:changeSelectedType()
	local context = self.context
	local editor = context:getSettings()
	local editorChanges = context:getEditorChanges()

	editorChanges:reset()

	for _, note in pairs(context:getSelectedNotes()) do
		self:getNoteOps():changeType(note, editor.snap)
	end

	context:resetVisual()
	editorChanges:next()
end

function EditorNoteCommandService:flipSelected()
	local context = self.context
	local noteSkin = assert(context:getNoteSkin())

	self:getNoteOps():flipSelected(context:getSelectedNotes(), noteSkin)
end

return EditorNoteCommandService
