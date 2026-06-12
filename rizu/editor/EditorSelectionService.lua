local class = require("class")

---@class rizu.editor.EditorSelectionRectContext
---@field getSelectionState fun(self: rizu.editor.EditorSelectionRectContext): rizu.editor.EditorSelectionState
---@field getMousePosition fun(self: rizu.editor.EditorSelectionRectContext): number, number
---@field getMouseTime fun(self: rizu.editor.EditorSelectionRectContext): number
---@field selectRegion fun(self: rizu.editor.EditorSelectionRectContext, x1: number, y1: number, x2: number, y2: number)
---@field unselectRegion fun(self: rizu.editor.EditorSelectionRectContext)

---@class rizu.editor.EditorSelectionService
---@operator call: rizu.editor.EditorSelectionService
local EditorSelectionService = class()

---@param visualEngine rizu.editor.VisualEngine
---@param isMultiSelectRequested fun(): boolean
---@param note rizu.editor.EditorNote
function EditorSelectionService:selectNote(visualEngine, isMultiSelectRequested, note)
	visualEngine:selectNote(note, isMultiSelectRequested())
end

---@param visualEngine rizu.editor.VisualEngine
---@param context rizu.editor.EditorSelectionRectContext
function EditorSelectionService:selectStart(visualEngine, context)
	visualEngine:selectStart()
	local mx, my = context:getMousePosition()
	context:getSelectionState():start(mx, my, context:getMouseTime())
	context:selectRegion(mx, my, mx, my)
end

---@param visualEngine rizu.editor.VisualEngine
---@param context rizu.editor.EditorSelectionRectContext
function EditorSelectionService:selectEnd(visualEngine, context)
	visualEngine:selectEnd()
	context:getSelectionState():finish()
	context:unselectRegion()
end

---@param context rizu.editor.EditorSelectionRectContext
---@param editor table
---@param noteSkin table
---@param time number
function EditorSelectionService:updateSelectionRect(context, editor, noteSkin, time)
	local selectionState = context:getSelectionState()
	local rect = selectionState:getRect()
	local startTime = selectionState:getStartTime()
	if rect and startTime then
		local mx, my = context:getMousePosition()
		local rectY = noteSkin:getTimePosition((time - startTime) * editor.speed)
		selectionState:update(mx, my, rectY)
		context:selectRegion(rect[1], rect[2], mx, my)
	end
end

return EditorSelectionService
