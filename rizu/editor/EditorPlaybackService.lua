local class = require("class")

---@class rizu.editor.EditorPlaybackService
---@operator call: rizu.editor.EditorPlaybackService
local EditorPlaybackService = class()

---@class rizu.editor.EditorPlaybackContext
---@field timer rizu.editor.TimeManager
---@field audio_engine rizu.engine.audio.Engine
---@field chart sea.Chart
---@field intervalManager rizu.editor.IntervalManager

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
	audioEngine:load(chart, resources)
	audioEngine:setPosition(timer:getTime())
end

---@param timer rizu.editor.TimeManager
---@param audioEngine rizu.engine.audio.Engine
---@param isIntervalGrabbed fun(): boolean
function EditorPlaybackService:play(timer, audioEngine, isIntervalGrabbed)
	if isIntervalGrabbed() then
		return
	end
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
	self:setTime(context.timer, context.audio_engine, time)
end

---@param context rizu.editor.EditorPlaybackContext
---@param resources {[string]: string}
function EditorPlaybackService:loadEditorAudioResources(context, resources)
	self:loadAudioResources(context.audio_engine, context.timer, context.chart, resources)
end

---@param context rizu.editor.EditorPlaybackContext
function EditorPlaybackService:playEditor(context)
	self:play(context.timer, context.audio_engine, function()
		return context.intervalManager:isGrabbed()
	end)
end

---@param context rizu.editor.EditorPlaybackContext
function EditorPlaybackService:pauseEditor(context)
	self:pause(context.timer, context.audio_engine)
end

return EditorPlaybackService
