local class = require("class")

---@class rizu.editor.EditorBmsOverlayContext
---@field getBmsToolsContext fun(self: rizu.editor.EditorBmsOverlayContext): rizu.editor.BmsToolsContext
---@field applyBmsOffsetTempo fun(self: rizu.editor.EditorBmsOverlayContext)
---@field changeBmsOffset fun(self: rizu.editor.EditorBmsOverlayContext, delta: number)
---@field sliceKeysounds fun(self: rizu.editor.EditorBmsOverlayContext)
---@field exportBmsTemplate fun(self: rizu.editor.EditorBmsOverlayContext, columnsOut: integer)
---@field exportUBmsC fun(self: rizu.editor.EditorBmsOverlayContext)

---@class rizu.editor.EditorBmsOverlayService
---@operator call: rizu.editor.EditorBmsOverlayService
local EditorBmsOverlayService = class()

---@param context rizu.editor.EditorBmsOverlayContext
---@return rizu.editor.BmsToolsContext
function EditorBmsOverlayService:getBmsToolsContext(context)
	return context:getBmsToolsContext()
end

---@param context rizu.editor.EditorBmsOverlayContext
---@param offset number
---@param tempo number
function EditorBmsOverlayService:setOffsetTempo(context, offset, tempo)
	local bmsToolsContext = context:getBmsToolsContext()
	bmsToolsContext.offset = offset
	bmsToolsContext.tempo = tempo
end

---@param context rizu.editor.EditorBmsOverlayContext
---@param beatOffset number
function EditorBmsOverlayService:setBeatOffset(context, beatOffset)
	context:getBmsToolsContext().beat_offset = beatOffset
end

---@param context rizu.editor.EditorBmsOverlayContext
function EditorBmsOverlayService:applyOffsetTempo(context)
	context:applyBmsOffsetTempo()
end

---@param context rizu.editor.EditorBmsOverlayContext
---@param delta number
function EditorBmsOverlayService:changeOffset(context, delta)
	context:changeBmsOffset(delta)
end

---@param context rizu.editor.EditorBmsOverlayContext
function EditorBmsOverlayService:sliceKeysounds(context)
	context:sliceKeysounds()
end

---@param context rizu.editor.EditorBmsOverlayContext
---@param columnsOut integer
function EditorBmsOverlayService:exportBmsTemplate(context, columnsOut)
	context:exportBmsTemplate(columnsOut)
end

---@param context rizu.editor.EditorBmsOverlayContext
function EditorBmsOverlayService:exportUBmsC(context)
	context:exportUBmsC()
end

return EditorBmsOverlayService
