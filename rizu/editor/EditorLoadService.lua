local class = require("class")
local EditorPlaybackService = require("rizu.editor.EditorPlaybackService")

---@class rizu.editor.EditorLoadContext
---@field setLoaded fun(loaded: boolean)
---@field getSettings fun(): table
---@field noteChartLoader rizu.editor.NoteChartLoader
---@field setChartData fun(layer: chartedit.Layer, notes: chartedit.Notes)
---@field setVisual fun(visual: chartedit.Visual?)
---@field sessionResetService rizu.editor.EditorSessionResetService
---@field createSessionResetContext fun(): rizu.editor.EditorSessionResetContext
---@field playbackService rizu.editor.EditorPlaybackService?
---@field timer rizu.editor.TimeManager
---@field audio_engine rizu.engine.audio.Engine
---@field getAudioSettings fun(): table
---@field configModel sphere.ConfigModel
---@field metronome rizu.editor.Metronome
---@field scroller rizu.editor.Scroller
---@field bmsToolsContext rizu.editor.BmsToolsContext
---@field metadata chart.sph.Metadata
---@field chartmeta table

---@class rizu.editor.EditorLoadService
---@operator call: rizu.editor.EditorLoadService
local EditorLoadService = class()

---@param context rizu.editor.EditorLoadContext
function EditorLoadService:load(context)
	context.setLoaded(true)

	local editor = context.getSettings()
	local playbackService = context.playbackService or EditorPlaybackService()

	local layer, notes = context.noteChartLoader:load()
	context.setChartData(layer, notes)
	context.setVisual(layer.visuals.main or layer.visuals[""])

	context.sessionResetService:reset(context.createSessionResetContext())
	playbackService:loadTimer(context.timer, editor)
	playbackService:loadAudio(context.audio_engine, context.getAudioSettings())

	local volume = context.configModel.configs.settings.audio.volume
	context.metronome.volume = volume
	context.metronome:load()

	context.scroller:scrollSeconds(context.timer:getTime())
	context.bmsToolsContext:initFromLayer(layer)

	context.metadata:new()
	context.metadata:fromChartmeta(context.chartmeta)
end

return EditorLoadService
