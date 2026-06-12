local class = require("class")

---@class rizu.editor.EditorSelectionService
---@operator call: rizu.editor.EditorSelectionService
local EditorSelectionService = class()

---@param editorModel rizu.editor.EditorModel
---@param note rizu.editor.EditorNote
function EditorSelectionService:selectNote(editorModel, note)
	editorModel.visualEngine:selectNote(note, editorModel.isMultiSelectRequested())
end

---@param editorModel rizu.editor.EditorModel
function EditorSelectionService:selectStart(editorModel)
	editorModel.visualEngine:selectStart()
	local mx, my = editorModel.getMousePosition()
	local selectionState = editorModel:getSelectionState()
	selectionState:start(mx, my, editorModel:getMouseTime())
	editorModel.selectRegion(mx, my, mx, my)
end

---@param editorModel rizu.editor.EditorModel
function EditorSelectionService:selectEnd(editorModel)
	editorModel.visualEngine:selectEnd()
	editorModel:getSelectionState():finish()
	editorModel.unselectRegion()
end

---@param editorModel rizu.editor.EditorModel
---@param editor table
---@param noteSkin table
---@param time number
function EditorSelectionService:updateSelectionRect(editorModel, editor, noteSkin, time)
	local selectionState = editorModel:getSelectionState()
	local rect = selectionState:getRect()
	local startTime = selectionState:getStartTime()
	if rect and startTime then
		local mx, my = editorModel.getMousePosition()
		local rectY = noteSkin:getTimePosition((time - startTime) * editor.speed)
		selectionState:update(mx, my, rectY)
		editorModel.selectRegion(rect[1], rect[2], mx, my)
	end
end

return EditorSelectionService
