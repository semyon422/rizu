local class = require("class")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")

---@class rizu.editor.NoteCreator
---@operator call: rizu.editor.NoteCreator
---@field noteManager rizu.editor.NoteManager
local NoteCreator = class()

---@param noteManager rizu.editor.NoteManager
function NoteCreator:new(noteManager)
	self.noteManager = noteManager
end

---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote?
function NoteCreator:newNote(noteType, absoluteTime, column)
	local editorModel = self.noteManager.editorModel
	local note = EditorNoteFactory:newNote_t(noteType, editorModel.visualEngine.visual_info)
	if not note then
		return
	end
	note.editorModel = editorModel
	note.visualEngine = editorModel.visualEngine
	note.column = column
	return note:create(absoluteTime, column)
end

---@param absoluteTime number
---@param column string
function NoteCreator:addNote(absoluteTime, column)
	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel
	local editor = editorModel:getSettings()
	editorModel.visualEngine:selectNote()

	local note
	if editor.tool == "ShortNote" then
		note = self:newNote("tap", absoluteTime, column)
	elseif editor.tool == "LongNote" then
		note = self:newNote("hold", absoluteTime, column)
	end

	if not note then
		return
	end

	editorModel.visualEngine:selectNote(note)
	if editor.tool == "ShortNote" then
		noteManager.dragSession:grabNew(note, "head", editorModel:getMouseTime())
	elseif editor.tool == "LongNote" then
		noteManager.dragSession:grabNew(
			note,
			"tail",
			editorModel:getMouseTime() +
			note.endNote:getTime() -
			note.startNote:getTime()
		)
	end
end

return NoteCreator
