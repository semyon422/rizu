local class = require("class")

---@class rizu.editor.EditorClipboardService
---@operator call: rizu.editor.EditorClipboardService
---@field editorModel rizu.editor.EditorModel
---@field commandService rizu.editor.EditorNoteCommandService
---@field copiedNotes rizu.editor.EditorNote[]?
local EditorClipboardService = class()

---@param commandService rizu.editor.EditorNoteCommandService
function EditorClipboardService:new(commandService)
	self.commandService = commandService
end

---@param editorModel rizu.editor.EditorModel
function EditorClipboardService:setEditorModel(editorModel)
	self.editorModel = editorModel
end

---@param cut boolean?
function EditorClipboardService:copy(cut)
	local editorModel = self.editorModel

	if cut then
		editorModel.editorChanges:reset()
	end

	---@type rizu.editor.EditorNote[]
	self.copiedNotes = {}
	local copyPoint

	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		if not copyPoint or note.startNote.visualPoint.point < copyPoint then
			copyPoint = note.startNote.visualPoint.point
		end
		table.insert(self.copiedNotes, note)
		if cut then
			self.commandService:removeNoteWithoutUndoBoundary(note)
		end
	end

	for _, note in ipairs(self.copiedNotes) do
		note:copy(copyPoint)
	end

	if cut then
		editorModel.editorChanges:next()
	end
end

function EditorClipboardService:paste()
	local copiedNotes = self.copiedNotes
	if not copiedNotes then
		return
	end

	local editorModel = self.editorModel

	editorModel.editorChanges:reset()
	local point = editorModel:getPoint()
	for _, note in ipairs(copiedNotes) do
		self.commandService:addNotes(note:paste(point))
	end
	editorModel.editorChanges:next()
end

return EditorClipboardService
