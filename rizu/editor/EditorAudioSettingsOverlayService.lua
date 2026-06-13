local class = require("class")

---@class rizu.editor.EditorAudioSettingsOverlayState
---@field audio table
---@field editor table
---@field waveform table

---@class rizu.editor.EditorAudioSettingsOverlayContext
---@field getAudioSettings fun(self: rizu.editor.EditorAudioSettingsOverlayContext): table
---@field getEditorSettings fun(self: rizu.editor.EditorAudioSettingsOverlayContext): table

---@class rizu.editor.EditorAudioSettingsOverlayService
---@operator call: rizu.editor.EditorAudioSettingsOverlayService
local EditorAudioSettingsOverlayService = class()

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@return rizu.editor.EditorAudioSettingsOverlayState
function EditorAudioSettingsOverlayService:getState(context)
	local editor = context:getEditorSettings()
	return {
		audio = context:getAudioSettings(),
		editor = editor,
		waveform = editor.waveform,
	}
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param key string
---@param value number
function EditorAudioSettingsOverlayService:setVolume(context, key, value)
	context:getAudioSettings().volume[key] = value
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param audioOffset number
function EditorAudioSettingsOverlayService:setAudioOffset(context, audioOffset)
	context:getEditorSettings().audioOffset = audioOffset
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param waveformOffset number
function EditorAudioSettingsOverlayService:setWaveformOffset(context, waveformOffset)
	context:getEditorSettings().waveformOffset = waveformOffset
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param opacity number
function EditorAudioSettingsOverlayService:setWaveformOpacity(context, opacity)
	context:getEditorSettings().waveform.opacity = opacity
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param scale number
function EditorAudioSettingsOverlayService:setWaveformScale(context, scale)
	context:getEditorSettings().waveform.scale = scale
end

return EditorAudioSettingsOverlayService
