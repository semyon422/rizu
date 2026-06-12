local class = require("class")

---@class rizu.editor.NoteClipboard
---@operator call: rizu.editor.NoteClipboard
---@field noteManager rizu.editor.NoteManager
---@field copiedNotes rizu.editor.EditorNote[]?
local NoteClipboard = class()

---@param noteManager rizu.editor.NoteManager
function NoteClipboard:new(noteManager)
	self.noteManager = noteManager
end

---@param cut boolean?
function NoteClipboard:copy(cut)
	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel

	if cut then
		editorModel.editorChanges:reset()
	end

	self.copiedNotes = {}
	local copyPoint

	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		if not copyPoint or note.startNote.visualPoint.point < copyPoint then
			copyPoint = note.startNote.visualPoint.point
		end
		table.insert(self.copiedNotes, note)
		if cut then
			noteManager:_removeNote(note)
		end
	end

	for _, note in ipairs(self.copiedNotes) do
		note:copy(copyPoint)
	end

	if cut then
		editorModel.editorChanges:next()
	end
end

function NoteClipboard:paste()
	local copiedNotes = self.copiedNotes
	if not copiedNotes then
		return
	end

	local noteManager = self.noteManager
	local editorModel = noteManager.editorModel

	editorModel.editorChanges:reset()
	local point = editorModel:getPoint()
	for _, note in ipairs(copiedNotes) do
		noteManager:_addNotes(note:paste(point))
	end
	editorModel.editorChanges:next()
end

return NoteClipboard
