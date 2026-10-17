local class = require("class")

---@class rizu.editor.EditorPlaybackService
---@operator call: rizu.editor.EditorPlaybackService
local EditorPlaybackService = class()

---@class rizu.editor.EditorPlaybackContext
---@field getTimer fun(self: rizu.editor.EditorPlaybackContext): rizu.editor.TimeManager
---@field getAudioEngine fun(self: rizu.editor.EditorPlaybackContext): rizu.engine.audio.Engine
---@field getChart fun(self: rizu.editor.EditorPlaybackContext): chart.Chart
---@field getIntervalManager fun(self: rizu.editor.EditorPlaybackContext): rizu.editor.IntervalManager
---@param timer rizu.editor.TimeManager
---@param editor table
function EditorPlaybackService:loadTimer(timer, editor)
	timer:pause()
	timer:setTime(editor.time)
end

---@param audioEngine rizu.engine.audio.Engine
---@param audioSettings table
function EditorPlaybackService:loadAudio(audioEngine, audioSettings)
	local volume = audioSettings.volume
	audioEngine:setVolume(volume.master * volume.music, volume.master * volume.keysounds)
	audioEngine:setAudioMode(audioSettings.mode)
end

---@param timer rizu.editor.TimeManager
---@param audioEngine rizu.engine.audio.Engine
---@param time number
function EditorPlaybackService:setTime(timer, audioEngine, time)
	timer:setTime(time, true)
	audioEngine:setPosition(time)
end

---@param audioEngine rizu.engine.audio.Engine
---@param timer rizu.editor.TimeManager
---@param chart sea.Chart
---@param resources {[string]: string}
function EditorPlaybackService:loadAudioResources(audioEngine, timer, chart, resources)
	audioEngine:setEnabled(true)
	audioEngine:load(chart, resources, true)
	audioEngine:setRate(timer.rate)
	self:setTime(timer, audioEngine, timer:getTime())
	if timer.is_playing then
		audioEngine:play()
	end
end

---@param timer rizu.editor.TimeManager
---@param audioEngine rizu.engine.audio.Engine
---@param isIntervalGrabbed fun(): boolean
function EditorPlaybackService:play(timer, audioEngine, isIntervalGrabbed)
	if isIntervalGrabbed() then
		return
	end
	audioEngine:setPosition(timer:getTime())
	timer:play()
	audioEngine:play()
end

---@param timer rizu.editor.TimeManager
---@param audioEngine rizu.engine.audio.Engine
function EditorPlaybackService:pause(timer, audioEngine)
	timer:pause()
	audioEngine:pause()
end

---@param audioEngine rizu.engine.audio.Engine
function EditorPlaybackService:updateAudio(audioEngine)
	audioEngine:update()
end

---@param context rizu.editor.EditorPlaybackContext
---@param time number
function EditorPlaybackService:setEditorTime(context, time)
	self:setTime(context:getTimer(), context:getAudioEngine(), time)
end

---@param context rizu.editor.EditorPlaybackContext
---@param resources {[string]: string}
function EditorPlaybackService:loadEditorAudioResources(context, resources)
	self:loadAudioResources(context:getAudioEngine(), context:getTimer(), context:getChart(), resources)
end

---@param context rizu.editor.EditorPlaybackContext
function EditorPlaybackService:playEditor(context)
	self:play(context:getTimer(), context:getAudioEngine(), function()
		return context:getIntervalManager():isGrabbed()
	end)
end

---@param context rizu.editor.EditorPlaybackContext
function EditorPlaybackService:pauseEditor(context)
	self:pause(context:getTimer(), context:getAudioEngine())
end

return EditorPlaybackService
