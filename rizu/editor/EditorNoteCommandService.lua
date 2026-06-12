local class = require("class")
local EditorNoteOps = require("rizu.editor.EditorNoteOps")

---@class rizu.editor.EditorNoteCommandService
---@operator call: rizu.editor.EditorNoteCommandService
---@field editorModel rizu.editor.EditorModel
---@field noteOps rizu.editor.EditorNoteOps
local EditorNoteCommandService = class()

function EditorNoteCommandService:new()
	self.noteOps = EditorNoteOps()
end

---@param editorModel rizu.editor.EditorModel
function EditorNoteCommandService:setEditorModel(editorModel)
	self.editorModel = editorModel
end

---@return rizu.editor.EditorNoteOps
function EditorNoteCommandService:getNoteOps()
	self.noteOps.editorModel = self.editorModel
	return self.noteOps
end

---@param notes chart.Note[]
---@return boolean added
function EditorNoteCommandService:addNotes(notes)
	return self:getNoteOps():addNotes(notes)
end

---@param note rizu.editor.EditorNote
function EditorNoteCommandService:removeNoteWithoutUndoBoundary(note)
	local editorModel = self.editorModel
	editorModel.visualEngine.selectedNotes[note.startNote] = nil
	self:getNoteOps():removeNotes(note:getNotes())
end

---@param note rizu.editor.EditorNote
function EditorNoteCommandService:removeNote(note)
	local editorModel = self.editorModel
	editorModel.editorChanges:reset()
	self:removeNoteWithoutUndoBoundary(note)
	editorModel.editorChanges:next()
end

---@return number deleted
function EditorNoteCommandService:deleteSelected()
	local editorModel = self.editorModel
	return self:getNoteOps():deleteSelected(editorModel.visualEngine.selectedNotes)
end

function EditorNoteCommandService:changeSelectedType()
	local editorModel = self.editorModel
	local editor = editorModel:getSettings()

	editorModel.editorChanges:reset()

	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		self:getNoteOps():changeType(note, editor.snap)
	end

	editorModel.visualEngine:reset()
	editorModel.editorChanges:next()
end

function EditorNoteCommandService:flipSelected()
	local editorModel = self.editorModel
	local noteSkin = assert(editorModel:getNoteSkin())

	self:getNoteOps():flipSelected(editorModel.visualEngine.selectedNotes, noteSkin)
end

return EditorNoteCommandService
