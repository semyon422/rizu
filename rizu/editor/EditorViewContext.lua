local class = require("class")

---@class rizu.editor.EditorViewContext: rizu.editor.EditorSelectionRectContext, rizu.editor.EditorModelFrameContext, rizu.editor.EditorSettingsContext, rizu.editor.VisualEngineContext, rizu.editor.EditorChangesContext
---@operator call: rizu.editor.EditorViewContext
---@field model rizu.editor.EditorModel
local EditorViewContext = class()

---@param model rizu.editor.EditorModel
function EditorViewContext:new(model)
	self.model = model
end

---@return rizu.editor.EditorSelectionState
function EditorViewContext:getSelectionState()
	return self.model:getSelectionState()
end

---@return number
---@return number
function EditorViewContext:getMousePosition()
	return self.model.getMousePosition()
end

---@return number
function EditorViewContext:getMouseTime()
	return self.model:getMouseTime()
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function EditorViewContext:selectRegion(x1, y1, x2, y2)
	self.model.selectRegion(x1, y1, x2, y2)
end

function EditorViewContext:unselectRegion()
	self.model.unselectRegion()
end

---@return table
function EditorViewContext:getSettings()
	return self.model:getSettings()
end

---@return table
function EditorViewContext:getEditorSettings()
	return self.model.configModel.configs.settings.editor
end

---@return table?
function EditorViewContext:getNoteSkin()
	return self.model:getNoteSkin()
end

---@return rizu.editor.TimeManager
function EditorViewContext:getTimer()
	return self.model.timer
end

---@return rizu.editor.EditorNoteService
function EditorViewContext:getNoteService()
	return self.model.noteService
end

---@return rizu.editor.Metronome
function EditorViewContext:getMetronome()
	return self.model.metronome
end

---@return rizu.editor.EditorSelectionService
function EditorViewContext:getSelectionService()
	return self.model.selectionService
end

---@param absoluteTime number
---@return chartedit.Point?
function EditorViewContext:getDtpAbsolute(absoluteTime)
	return self.model:getDtpAbsolute(absoluteTime)
end

---@return rizu.editor.IntervalManager
function EditorViewContext:getIntervalManager()
	return self.model.intervalManager
end

---@return rizu.editor.EditorPlaybackService
function EditorViewContext:getPlaybackService()
	return self.model.playbackService
end

---@return rizu.engine.audio.Engine
function EditorViewContext:getAudioEngine()
	return self.model.audio_engine
end

---@param point chartedit.Point
function EditorViewContext:setSessionPoint(point)
	self.model:setSessionPoint(point)
end

---@return rizu.editor.VisualEngine
function EditorViewContext:getVisualEngine()
	return self.model.visualEngine
end

---@return sphere.ConfigModel
function EditorViewContext:getConfigModel()
	return self.model.configModel
end

---@return integer
function EditorViewContext:getMaxSnap()
	return self.model.max_snap
end

---@return number
function EditorViewContext:getSessionTime()
	return self.model:getSessionTime()
end

---@return chartedit.Point?
function EditorViewContext:getVisualPoint()
	return self.model.visualPoint
end

---@return chartedit.Visual?
function EditorViewContext:getVisual()
	return self.model:getVisual()
end

---@return chartedit.Notes
function EditorViewContext:getNotes()
	return self.model.notes
end

---@return number
---@return number
function EditorViewContext:getIterRange()
	return self.model:getIterRange()
end

---@return rizu.editor.EditorNoteContext
function EditorViewContext:getEditorNoteContext()
	return self.model.context:getNoteEditContext()
end

function EditorViewContext:resetVisual()
	self.model.visualEngine:reset()
end

return EditorViewContext
