local class = require("class")

---@class rizu.editor.EditorClipboardServiceContext
---@field getSelectedNotes fun(): {[chart.Note]: rizu.editor.EditorNote}
---@field editorChanges rizu.editor.EditorChanges
---@field getPoint fun(): chartedit.Point

---@class rizu.editor.EditorClipboardService
---@operator call: rizu.editor.EditorClipboardService
---@field context rizu.editor.EditorClipboardServiceContext
---@field commandService rizu.editor.EditorNoteCommandService
---@field copiedNotes rizu.editor.EditorNote[]?
local EditorClipboardService = class()

---@param commandService rizu.editor.EditorNoteCommandService
function EditorClipboardService:new(commandService)
	self.commandService = commandService
end

---@param context rizu.editor.EditorClipboardServiceContext
function EditorClipboardService:setContext(context)
	self.context = context
end

---@param cut boolean?
function EditorClipboardService:copy(cut)
	local context = self.context

	if cut then
		context.editorChanges:reset()
	end

	---@type rizu.editor.EditorNote[]
	self.copiedNotes = {}
	local copyPoint

	for _, note in pairs(context.getSelectedNotes()) do
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
		context.editorChanges:next()
	end
end

function EditorClipboardService:paste()
	local copiedNotes = self.copiedNotes
	if not copiedNotes then
		return
	end

	local context = self.context

	context.editorChanges:reset()
	local point = context.getPoint()
	for _, note in ipairs(copiedNotes) do
		self.commandService:addNotes(note:paste(point))
	end
	context.editorChanges:next()
end

return EditorClipboardService
