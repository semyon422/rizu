local class = require("class")
local EditorDataContext = require("rizu.editor.contexts.EditorDataContext")
local EditorTimelineContext = require("rizu.editor.contexts.EditorTimelineContext")
local EditorViewContext = require("rizu.editor.contexts.EditorViewContext")
local EditorNoteEditContext = require("rizu.editor.contexts.EditorNoteEditContext")

---@class rizu.editor.EditorModelContext
---@operator call: rizu.editor.EditorModelContext
---@field model rizu.editor.EditorModel
---@field data rizu.editor.EditorDataContext
---@field timeline rizu.editor.EditorTimelineContext
---@field view rizu.editor.EditorViewContext
---@field noteEdit rizu.editor.EditorNoteEditContext
local EditorModelContext = class()

---@param model rizu.editor.EditorModel
function EditorModelContext:new(model)
	self.model = model
	self.data = EditorDataContext(model)
	self.timeline = EditorTimelineContext(model)
	self.view = EditorViewContext(model)
	self.noteEdit = EditorNoteEditContext(model)
end

---@return rizu.editor.EditorDataContext
function EditorModelContext:getDataContext()
	return self.data
end

---@return rizu.editor.EditorTimelineContext
function EditorModelContext:getTimelineContext()
	return self.timeline
end

---@return rizu.editor.EditorViewContext
function EditorModelContext:getViewContext()
	return self.view
end

---@return rizu.editor.EditorNoteEditContext
function EditorModelContext:getNoteEditContext()
	return self.noteEdit
end

---@return rizu.editor.EditorLoadContext
function EditorModelContext:getLoadContext()
	return self.data
end

---@return rizu.editor.EditorSaveContext
function EditorModelContext:getSaveContext()
	return self.data
end

---@return rizu.editor.EditorResourceLoadContext
function EditorModelContext:getResourceLoadContext()
	return self.data
end

---@return rizu.editor.EditorAnalysisContext
function EditorModelContext:getAnalysisContext()
	return self.data
end

---@return rizu.editor.NoteChartLoaderContext
function EditorModelContext:getNoteChartLoaderContext()
	return self.data
end

---@return rizu.editor.IntervalManagerContext
function EditorModelContext:getIntervalManagerContext()
	return self.data
end

---@return rizu.editor.EditorPlaybackContext
function EditorModelContext:getPlaybackContext()
	return self.timeline
end

---@return rizu.editor.ScrollerContext
function EditorModelContext:getScrollerContext()
	return self.timeline
end

---@return rizu.editor.MetronomeContext
function EditorModelContext:getMetronomeContext()
	return self.timeline
end

---@return rizu.editor.EditorSettingsContext
function EditorModelContext:getSettingsContext()
	return self.view
end

---@return rizu.editor.EditorSelectionRectContext
function EditorModelContext:getSelectionRectContext()
	return self.view
end

---@return rizu.editor.EditorModelFrameContext
function EditorModelContext:getFrameContext()
	return self.view
end

---@return rizu.editor.EditorNoteServiceContext
function EditorModelContext:getNoteServiceContext()
	return self.noteEdit
end

---@return rizu.editor.VisualEngineContext
function EditorModelContext:getVisualEngineContext()
	return self.view
end

---@return rizu.editor.EditorChangesContext
function EditorModelContext:getEditorChangesContext()
	return self.view
end

return EditorModelContext
