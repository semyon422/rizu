local class = require("class")

---@class rizu.editor.EditorLoadContext
---@field setLoaded fun(self: rizu.editor.EditorLoadContext, loaded: boolean)
---@field getSettings fun(self: rizu.editor.EditorLoadContext): table
---@field getPlaybackService fun(self: rizu.editor.EditorLoadContext): rizu.editor.EditorPlaybackService
---@field getNoteChartLoader fun(self: rizu.editor.EditorLoadContext): rizu.editor.NoteChartLoader
---@field setChartData fun(self: rizu.editor.EditorLoadContext, layer: chartedit.Layer, notes: chartedit.Notes)
---@field setVisual fun(self: rizu.editor.EditorLoadContext, visual: chartedit.Visual?)
---@field getSessionResetService fun(self: rizu.editor.EditorLoadContext): rizu.editor.EditorSessionResetService
---@field getSessionResetContext fun(self: rizu.editor.EditorLoadContext): rizu.editor.EditorSessionResetContext
---@field getTimer fun(self: rizu.editor.EditorLoadContext): rizu.editor.TimeManager
---@field getAudioEngine fun(self: rizu.editor.EditorLoadContext): rizu.engine.audio.Engine
---@field getAudioSettings fun(self: rizu.editor.EditorLoadContext): table
---@field getConfigModel fun(self: rizu.editor.EditorLoadContext): sphere.ConfigModel
---@field getMetronome fun(self: rizu.editor.EditorLoadContext): rizu.editor.Metronome
---@field getScroller fun(self: rizu.editor.EditorLoadContext): rizu.editor.Scroller
---@field getBmsToolsContext fun(self: rizu.editor.EditorLoadContext): rizu.editor.BmsToolsContext
---@field getMetadata fun(self: rizu.editor.EditorLoadContext): chart.sph.Metadata
---@field getChartmeta fun(self: rizu.editor.EditorLoadContext): table

---@class rizu.editor.EditorLoadService
---@operator call: rizu.editor.EditorLoadService
local EditorLoadService = class()

---@param context rizu.editor.EditorLoadContext
function EditorLoadService:load(context)
	context:setLoaded(true)

	local editor = context:getSettings()
	local playbackService = context:getPlaybackService()

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
