local class = require("class")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")

---@class rizu.editor.EditorLoadContext

---@class rizu.editor.EditorLoadService
---@operator call: rizu.editor.EditorLoadService
local EditorLoadService = class()

---@param context rizu.editor.EditorLoadContext
function EditorLoadService:load(context)
	context:setLoaded(true)

	local editor = context:getSettings()
	local playbackService = context:getPlaybackService() or EditorPlaybackService()

	local layer, notes = context:getNoteChartLoader():load()
	context:setChartData(layer, notes)
	context:setVisual(layer.visuals.main or layer.visuals[""])

	context:getSessionResetService():reset(context:getSessionResetContext())
	playbackService:loadTimer(context:getTimer(), editor)
	playbackService:loadAudio(context:getAudioEngine(), context:getAudioSettings())

	local volume = context:getConfigModel().configs.settings.audio.volume
	local metronome = context:getMetronome()
	metronome.volume = volume
	metronome:load()

	local timer = context:getTimer()
	context:getScroller():scrollSeconds(timer:getTime())
	context:getBmsToolsContext():initFromLayer(layer)

	local metadata = context:getMetadata()
	metadata:new()
	metadata:fromChartmeta(context:getChartmeta())
end

return EditorLoadService
