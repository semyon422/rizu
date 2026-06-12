local class = require("class")

---@class rizu.editor.EditorOverlayActionService
---@operator call: rizu.editor.EditorOverlayActionService
local EditorOverlayActionService = class()

---@param editorModel rizu.editor.EditorModel
function EditorOverlayActionService:setPreviewTimeToSession(editorModel)
	editorModel.chartmeta.preview_time = editorModel:getSessionTime()
end

---@param editorModel rizu.editor.EditorModel
---@param state string
function EditorOverlayActionService:setOverlayState(editorModel, state)
	editorModel.viewState:setOverlayState(state)
end

---@param editorModel rizu.editor.EditorModel
---@return string
function EditorOverlayActionService:getOverlayState(editorModel)
	return editorModel.viewState:getOverlayState()
end

---@param editorModel rizu.editor.EditorModel
function EditorOverlayActionService:changeSelectedNoteType(editorModel)
	editorModel.noteManager:changeType()
end

---@param editorModel rizu.editor.EditorModel
---@return boolean
function EditorOverlayActionService:scrollToFirstSelectedNote(editorModel)
	local _, note = next(editorModel.visualEngine.selectedNotes)
	if not note then
		return false
	end
	editorModel:scrollPoint(note.startNote.visualPoint.point)
	return true
end

---@param visualPoint chartedit.VisualPoint
---@param comment string?
function EditorOverlayActionService:setVisualPointComment(visualPoint, comment)
	if comment == "" then
		comment = nil
	end
	visualPoint.comment = comment
end

---@param visualPoint chartedit.VisualPoint
function EditorOverlayActionService:resetVisualPointComment(visualPoint)
	visualPoint.comment = nil
	visualPoint.temp_comment = nil
end

---@param editorModel rizu.editor.EditorModel
---@param comment string?
function EditorOverlayActionService:setSelectedNotesComment(editorModel, comment)
	if comment == "" then
		comment = nil
	end
	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		note.startNote.visualPoint.comment = comment
	end
end

---@param editorModel rizu.editor.EditorModel
function EditorOverlayActionService:resetSelectedNotesComment(editorModel)
	for _, note in pairs(editorModel.visualEngine.selectedNotes) do
		note.startNote.visualPoint.comment = nil
	end
end

---@param editorModel rizu.editor.EditorModel
function EditorOverlayActionService:applyBmsOffsetTempo(editorModel)
	editorModel.bmsToolsContext:resetOffsetTempo(editorModel.layer)
end

---@param editorModel rizu.editor.EditorModel
---@param delta number
function EditorOverlayActionService:changeBmsOffset(editorModel, delta)
	editorModel.bmsToolsContext.offset = editorModel.bmsToolsContext.offset + delta
	self:applyBmsOffsetTempo(editorModel)
end

return EditorOverlayActionService
