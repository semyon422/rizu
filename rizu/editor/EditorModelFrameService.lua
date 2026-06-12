local class = require("class")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")
local EditorSelectionService = require("rizu.editor.EditorSelectionService")

---@class rizu.editor.EditorModelFrameContext
---@field timer rizu.editor.TimeManager
---@field services rizu.editor.EditorServices?
---@field noteService rizu.editor.EditorNoteService
---@field metronome rizu.editor.Metronome
---@field selectionService rizu.editor.EditorSelectionService?
---@field playbackService rizu.editor.EditorPlaybackService?
---@field audio_engine rizu.engine.audio.Engine
---@field intervalManager rizu.editor.IntervalManager
---@field visualEngine rizu.editor.VisualEngine
---@field getSettings fun(): table
---@field getNoteSkin fun(): table?
---@field getDtpAbsolute fun(time: number): chartedit.Point
---@field setSessionPoint fun(point: chartedit.Point)
---@field createSelectionRectContext fun(): rizu.editor.EditorSelectionRectContext

---@class rizu.editor.EditorModelFrameService
---@operator call: rizu.editor.EditorModelFrameService
local EditorModelFrameService = class()

---@param context rizu.editor.EditorModelFrameContext
function EditorModelFrameService:update(context)
	local editor = context.getSettings()
	local noteSkin = assert(context.getNoteSkin())

	local time = context.timer:getTime()
	editor.time = time

	if context.services then
		context.services:update()
	else
		context.noteService:update()
		context.metronome:update()
	end

	(context.selectionService or EditorSelectionService()):updateSelectionRect(
		context.createSelectionRectContext(),
		editor,
		noteSkin,
		time
	)

	local dtp = context.getDtpAbsolute(time)
	if context.intervalManager.grabbedVertex then
		context.intervalManager:moveGrabbed(time)
	end
	(context.playbackService or EditorPlaybackService()):updateAudio(context.audio_engine)
	context.setSessionPoint(dtp)
	context.visualEngine:update()
end

---@param context rizu.editor.EditorModelFrameContext
---@param event table
function EditorModelFrameService:receive(context, event)
	if event.name == "framestarted" then
		context.timer:setGlobalTime(event.time)
	end
end

return EditorModelFrameService
