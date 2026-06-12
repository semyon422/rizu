local class = require("class")

---@class rizu.editor.EditorPlaybackService
---@operator call: rizu.editor.EditorPlaybackService
local EditorPlaybackService = class()

---@param editorModel rizu.editor.EditorModel
---@param editor table
function EditorPlaybackService:loadTimer(editorModel, editor)
	editorModel.timer:pause()
	editorModel.timer:setTime(editor.time)
end

---@param editorModel rizu.editor.EditorModel
function EditorPlaybackService:loadAudio(editorModel)
	local volume = editorModel.configModel.configs.settings.audio.volume
	editorModel.audio_engine:setVolume(volume.master * volume.music, volume.master * volume.keysounds)
	editorModel.audio_engine:setAudioMode(editorModel.configModel.configs.settings.audio.mode)
end

---@param editorModel rizu.editor.EditorModel
---@param time number
function EditorPlaybackService:setTime(editorModel, time)
	editorModel.timer:setTime(time, true)
	editorModel.audio_engine:setPosition(time)
end

---@param editorModel rizu.editor.EditorModel
---@param resources {[string]: string}
function EditorPlaybackService:loadAudioResources(editorModel, resources)
	editorModel.audio_engine:setEnabled(true)
	editorModel.audio_engine:load(editorModel.chart, resources)
	editorModel.audio_engine:setPosition(editorModel.timer:getTime())
end

---@param editorModel rizu.editor.EditorModel
function EditorPlaybackService:play(editorModel)
	if editorModel.intervalManager:isGrabbed() then
		return
	end
	editorModel.timer:play()
	editorModel.audio_engine:play()
end

---@param editorModel rizu.editor.EditorModel
function EditorPlaybackService:pause(editorModel)
	editorModel.timer:pause()
	editorModel.audio_engine:pause()
end

---@param editorModel rizu.editor.EditorModel
function EditorPlaybackService:updateAudio(editorModel)
	editorModel.audio_engine:update()
end

return EditorPlaybackService
