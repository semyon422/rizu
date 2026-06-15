local class = require("class")

---@class rizu.editor.EditorNoteEditContext: rizu.editor.EditorNoteServiceContext, rizu.editor.EditorNoteOpsContext, rizu.editor.EditorNoteContext
---@operator call: rizu.editor.EditorNoteEditContext
---@field model rizu.editor.EditorModel
local EditorNoteEditContext = class()

---@param model rizu.editor.EditorModel
function EditorNoteEditContext:new(model)
	self.model = model
end

---@return table?
function EditorNoteEditContext:getNoteSkin()
	return self.model:getNoteSkin()
end

---@return table
function EditorNoteEditContext:getSettings()
	return self.model:getSettings()
end

---@return {[chart.Note]: rizu.editor.EditorNote}
function EditorNoteEditContext:getSelectedNotes()
	return self.model.visualEngine.selectedNotes
end

---@return number
function EditorNoteEditContext:getMouseTime()
	return self.model:getMouseTime()
end

---@return rizu.editor.EditorChanges
function EditorNoteEditContext:getEditorChanges()
	return self.model.editorChanges
end

---@return number
---@return number
function EditorNoteEditContext:getMousePosition()
	return self.model.getMousePosition()
end

---@return rizu.editor.EditorNoteOpsContext
function EditorNoteEditContext:getNoteOpsContext()
	return self
end

---@return chartedit.Point
function EditorNoteEditContext:getPoint()
	return self.model:getPoint()
end

function EditorNoteEditContext:resetVisual()
	self.model.visualEngine:reset()
end

---@return rizu.VisualInfo
function EditorNoteEditContext:getVisualInfo()
	return self.model.visualEngine.visual_info
end

---@return rizu.editor.EditorNoteContext
function EditorNoteEditContext:getEditorNoteContext()
	return self
end

---@return rizu.editor.VisualEngine
function EditorNoteEditContext:getVisualEngine()
	return self.model.visualEngine
end

---@param note rizu.editor.EditorNote?
function EditorNoteEditContext:selectNote(note)
	self.model.visualEngine:selectNote(note)
end

---@param absoluteTime number
---@return chartedit.Point?
function EditorNoteEditContext:getDtpAbsolute(absoluteTime)
	return self.model:getDtpAbsolute(absoluteTime)
end

---@return chartedit.Layer
function EditorNoteEditContext:getLayer()
	return self.model.layer
end

---@return chartedit.Visual?
function EditorNoteEditContext:getVisual()
	return self.model:getVisual()
end

---@param point chartedit.Point
---@param delta number
---@return chartedit.Vertex
---@return chart.Fraction
function EditorNoteEditContext:getNextSnapIntervalTime(point, delta)
	return self.model.scroller:getNextSnapIntervalTime(point, delta)
end

---@return chartedit.Notes
function EditorNoteEditContext:getNotes()
	return self.model.notes
end

return EditorNoteEditContext
