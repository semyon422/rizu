local class = require("class")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")

---@class rizu.editor.EditorNoteCreateService
---@operator call: rizu.editor.EditorNoteCreateService
---@field editorModel rizu.editor.EditorModel
---@field dragService rizu.editor.EditorNoteDragService
local EditorNoteCreateService = class()

---@param dragService rizu.editor.EditorNoteDragService
function EditorNoteCreateService:new(dragService)
	self.dragService = dragService
end

---@param editorModel rizu.editor.EditorModel
function EditorNoteCreateService:setEditorModel(editorModel)
	self.editorModel = editorModel
end

---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote?
function EditorNoteCreateService:newNote(noteType, absoluteTime, column)
	local editorModel = self.editorModel
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
function EditorNoteCreateService:addNote(absoluteTime, column)
	local editorModel = self.editorModel
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
		self.dragService:grabNew(note, "head", editorModel:getMouseTime())
	elseif editor.tool == "LongNote" then
		self.dragService:grabNew(
			note,
			"tail",
			editorModel:getMouseTime() +
			note.endNote:getTime() -
			note.startNote:getTime()
		)
	end
end

return EditorNoteCreateService
