local class = require("class")
local EditorNoteFactory = require("rizu.editor.EditorNoteFactory")

---@class rizu.editor.EditorNoteCreateServiceContext
---@field getVisualInfo fun(): rizu.VisualInfo
---@field getEditorModel fun(): rizu.editor.EditorModel
---@field getVisualEngine fun(): rizu.editor.VisualEngine
---@field getSettings fun(): table
---@field selectNote fun(note: rizu.editor.EditorNote?)
---@field getMouseTime fun(): number

---@class rizu.editor.EditorNoteCreateService
---@operator call: rizu.editor.EditorNoteCreateService
---@field context rizu.editor.EditorNoteCreateServiceContext
---@field dragService rizu.editor.EditorNoteDragService
local EditorNoteCreateService = class()

---@param dragService rizu.editor.EditorNoteDragService
function EditorNoteCreateService:new(dragService)
	self.dragService = dragService
end

---@param context rizu.editor.EditorNoteCreateServiceContext
function EditorNoteCreateService:setContext(context)
	self.context = context
end

---@param editorModel rizu.editor.EditorModel
function EditorNoteCreateService:setEditorModel(editorModel)
	self:setContext({
		getVisualInfo = function()
			return editorModel.visualEngine.visual_info
		end,
		getEditorModel = function()
			return editorModel
		end,
		getVisualEngine = function()
			return editorModel.visualEngine
		end,
		getSettings = function()
			return editorModel:getSettings()
		end,
		selectNote = function(note)
			editorModel.visualEngine:selectNote(note)
		end,
		getMouseTime = function()
			return editorModel:getMouseTime()
		end,
	})
end

---@param noteType string
---@param absoluteTime number
---@param column string
---@return rizu.editor.EditorNote?
function EditorNoteCreateService:newNote(noteType, absoluteTime, column)
	local context = self.context
	local note = EditorNoteFactory:newNote_t(noteType, context.getVisualInfo())
	if not note then
		return
	end
	note.editorModel = context.getEditorModel()
	note.visualEngine = context.getVisualEngine()
	note.column = column
	return note:create(absoluteTime, column)
end

---@param absoluteTime number
---@param column string
function EditorNoteCreateService:addNote(absoluteTime, column)
	local context = self.context
	local editor = context.getSettings()
	context.selectNote()

	local note
	if editor.tool == "ShortNote" then
		note = self:newNote("tap", absoluteTime, column)
	elseif editor.tool == "LongNote" then
		note = self:newNote("hold", absoluteTime, column)
	end

	if not note then
		return
	end

	context.selectNote(note)
	if editor.tool == "ShortNote" then
		self.dragService:grabNew(note, "head", context.getMouseTime())
	elseif editor.tool == "LongNote" then
		self.dragService:grabNew(
			note,
			"tail",
			context.getMouseTime() +
			note.endNote:getTime() -
			note.startNote:getTime()
		)
	end
end

return EditorNoteCreateService
