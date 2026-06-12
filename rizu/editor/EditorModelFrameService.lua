local class = require("class")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")
local EditorSelectionService = require("rizu.editor.EditorSelectionService")

---@class rizu.editor.EditorModelFrameContext

---@class rizu.editor.EditorModelFrameService
---@operator call: rizu.editor.EditorModelFrameService
local EditorModelFrameService = class()

---@param context rizu.editor.EditorModelFrameContext
function EditorModelFrameService:update(context)
	local editor = context:getSettings()
	local noteSkin = assert(context:getNoteSkin())

	local timer = context:getTimer()
	local time = timer:getTime()
	editor.time = time

	local services = context:getServices()
	if services then
		services:update()
	else
		context:getNoteService():update()
		context:getMetronome():update()
	end

	(context:getSelectionService() or EditorSelectionService()):updateSelectionRect(
		context,
		editor,
		noteSkin,
		time
	)

	local dtp = context:getDtpAbsolute(time)
	local intervalManager = context:getIntervalManager()
	if intervalManager.grabbedVertex then
		intervalManager:moveGrabbed(time)
	end
	(context:getPlaybackService() or EditorPlaybackService()):updateAudio(context:getAudioEngine())
	context:setSessionPoint(dtp)
	context:getVisualEngine():update()
end

---@param context rizu.editor.EditorModelFrameContext
---@param event table
function EditorModelFrameService:receive(context, event)
	if event.name == "framestarted" then
		context:getTimer():setGlobalTime(event.time)
	end
end

return EditorModelFrameService
