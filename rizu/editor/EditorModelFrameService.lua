local class = require("class")

---@class rizu.editor.EditorModelFrameContext: rizu.editor.EditorSelectionRectContext
---@field getSettings fun(self: rizu.editor.EditorModelFrameContext): table
---@field getNoteSkin fun(self: rizu.editor.EditorModelFrameContext): table?
---@field getTimer fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.TimeManager
---@field getNoteService fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.EditorNoteService
---@field getMetronome fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.Metronome
---@field getSelectionService fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.EditorSelectionService
---@field getDtpAbsolute fun(self: rizu.editor.EditorModelFrameContext, time: number): chartedit.Point
---@field getIntervalManager fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.IntervalManager
---@field getPlaybackService fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.EditorPlaybackService
---@field getAudioEngine fun(self: rizu.editor.EditorModelFrameContext): rizu.engine.audio.Engine
---@field setSessionPoint fun(self: rizu.editor.EditorModelFrameContext, point: chartedit.Point)
---@field getVisualEngine fun(self: rizu.editor.EditorModelFrameContext): rizu.editor.VisualEngine

---@class rizu.editor.EditorModelFrameService
---@operator call: rizu.editor.EditorModelFrameService
local EditorModelFrameService = class()

---@param context rizu.editor.EditorModelFrameContext
---@param editor table
---@return number time
function EditorModelFrameService:syncEditorTime(context, editor)
	local timer = context:getTimer()
	local time = timer:getTime()
	editor.time = time
	return time
end

---@param context rizu.editor.EditorModelFrameContext
function EditorModelFrameService:updateServices(context)
	context:getNoteService():update()
	context:getMetronome():update()
end

---@param context rizu.editor.EditorModelFrameContext
---@param editor table
---@param noteSkin table
---@param time number
function EditorModelFrameService:updateSelection(context, editor, noteSkin, time)
	context:getSelectionService():updateSelectionRect(
		context,
		editor,
		noteSkin,
		time
	)
end

---@param context rizu.editor.EditorModelFrameContext
---@param time number
function EditorModelFrameService:updateTimingDrag(context, time)
	local intervalManager = context:getIntervalManager()
	if intervalManager.grabbedVertex then
		intervalManager:moveGrabbed(time)
	end
end

---@param context rizu.editor.EditorModelFrameContext
function EditorModelFrameService:updateAudio(context)
	context:getPlaybackService():updateAudio(context:getAudioEngine())
end

---@param context rizu.editor.EditorModelFrameContext
---@param time number
---@return chartedit.Point
function EditorModelFrameService:getCursorPoint(context, time)
	return context:getDtpAbsolute(time)
end

---@param context rizu.editor.EditorModelFrameContext
---@param point chartedit.Point
function EditorModelFrameService:setCursorPoint(context, point)
	context:setSessionPoint(point)
end

---@param context rizu.editor.EditorModelFrameContext
function EditorModelFrameService:updateVisuals(context)
	context:getVisualEngine():update()
end

---@param context rizu.editor.EditorModelFrameContext
function EditorModelFrameService:update(context)
	local editor = context:getSettings()
	local noteSkin = assert(context:getNoteSkin())
	local time = self:syncEditorTime(context, editor)

	self:updateServices(context)
	self:updateSelection(context, editor, noteSkin, time)
	local cursorPoint = self:getCursorPoint(context, time)
	self:updateTimingDrag(context, time)
	self:updateAudio(context)
	self:setCursorPoint(context, cursorPoint)
	self:updateVisuals(context)
end

---@param context rizu.editor.EditorModelFrameContext
---@param event table
function EditorModelFrameService:receive(context, event)
	if event.name == "framestarted" then
		context:getTimer():setGlobalTime(event.time)
	end
end

return EditorModelFrameService
