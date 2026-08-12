local class = require("class")
local decibel = require("decibel")

---@class rizu.editor.EditorAudioVolumeSettings
---@field master number
---@field music number
---@field keysounds number
---@field metronome number
---@field [string] number

---@class rizu.editor.EditorAudioModeSettings
---@field primary string
---@field secondary string

---@class rizu.editor.EditorAudioSettings
---@field volume rizu.editor.EditorAudioVolumeSettings
---@field volumeType string
---@field mode rizu.editor.EditorAudioModeSettings

---@class rizu.editor.EditorWaveformSettings
---@field opacity number
---@field scale number

---@class rizu.editor.EditorAudioEditorSettings
---@field audioOffset number
---@field waveformOffset number
---@field waveform rizu.editor.EditorWaveformSettings

---@class rizu.editor.EditorAudioSettingsOverlayState
---@field audio rizu.editor.EditorAudioSettings
---@field editor rizu.editor.EditorAudioEditorSettings
---@field waveform rizu.editor.EditorWaveformSettings
---@field volumeSliders rizu.editor.EditorAudioSettingsSlider[]
---@field audioOffsetSlider rizu.editor.EditorAudioSettingsSlider
---@field waveformOffsetSlider rizu.editor.EditorAudioSettingsSlider
---@field waveformOpacitySlider rizu.editor.EditorAudioSettingsSlider
---@field waveformScaleSlider rizu.editor.EditorAudioSettingsSlider
---@field primaryModeLabel string
---@field secondaryModeLabel string

---@class rizu.editor.EditorAudioSettingsSlider
---@field key string
---@field label string
---@field value number
---@field min number
---@field max number
---@field step number

---@class rizu.editor.EditorAudioSettingsOverlayInput
---@field volumes {[string]: number}
---@field audioOffsetMilliseconds number
---@field waveformOffsetMilliseconds number
---@field waveformOpacity number
---@field waveformScale number

---@class rizu.editor.EditorAudioSettingsOverlayContext
---@field getAudioSettings fun(self: rizu.editor.EditorAudioSettingsOverlayContext): rizu.editor.EditorAudioSettings
---@field getEditorSettings fun(self: rizu.editor.EditorAudioSettingsOverlayContext): rizu.editor.EditorAudioEditorSettings

---@class rizu.editor.EditorAudioSettingsOverlayService
---@operator call: rizu.editor.EditorAudioSettingsOverlayService
local EditorAudioSettingsOverlayService = class()

EditorAudioSettingsOverlayService.volumeKeys = {"master", "music", "keysounds", "metronome"}

---@param value number
---@return number
local function clampVolume(value)
	return math.min(math.max(value, 0), 1)
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@return rizu.editor.EditorAudioSettingsOverlayState
function EditorAudioSettingsOverlayService:getState(context)
	local editor = context:getEditorSettings()
	return {
		audio = context:getAudioSettings(),
		editor = editor,
		waveform = editor.waveform,
		volumeSliders = self:getVolumeSliders(context:getAudioSettings()),
		audioOffsetSlider = self:getOffsetSlider("ed.audioOffset", "main audio offset", editor.audioOffset),
		waveformOffsetSlider = self:getOffsetSlider("ed.waveformOffset", "waveform offset", editor.waveformOffset),
		waveformOpacitySlider = self:getUnitSlider("wf.opacity", "opacity", editor.waveform.opacity),
		waveformScaleSlider = self:getUnitSlider("wf.scale", "scale", editor.waveform.scale),
		primaryModeLabel = "primary: " .. context:getAudioSettings().mode.primary,
		secondaryModeLabel = "secondary: " .. context:getAudioSettings().mode.secondary,
	}
end

---@param audio rizu.editor.EditorAudioSettings
---@return rizu.editor.EditorAudioSettingsSlider[]
function EditorAudioSettingsOverlayService:getVolumeSliders(audio)
	---@type rizu.editor.EditorAudioSettingsSlider[]
	local sliders = {}
	---@type number
	local min
	---@type number
	local max
	---@type number
	local step
	---@type string
	local labelFormat
	if audio.volumeType == "linear" then
		min = 0
		max = 1
		step = 0.01
		labelFormat = "%s %0.2f"
	else
		min = -60
		max = 0
		step = 1
		labelFormat = "%s %ddB"
	end

	for i, key in ipairs(self.volumeKeys) do
		local value = clampVolume(audio.volume[key])
		if audio.volumeType ~= "linear" then
			value = math.floor(decibel.f_to_lf(math.max(value, decibel.lf_to_f(min))) / step + 0.5) * step
		end
		sliders[i] = {
			key = key,
			label = labelFormat:format(key, value),
			value = value,
			min = min,
			max = max,
			step = step,
		}
	end
	return sliders
end

---@param key string
---@param labelPrefix string
---@param seconds number
---@return rizu.editor.EditorAudioSettingsSlider
function EditorAudioSettingsOverlayService:getOffsetSlider(key, labelPrefix, seconds)
	local milliseconds = seconds * 1000
	return {
		key = key,
		label = ("%s %dms"):format(labelPrefix, milliseconds),
		value = milliseconds,
		min = -200,
		max = 200,
		step = 1,
	}
end

---@param key string
---@param labelPrefix string
---@param value number
---@return rizu.editor.EditorAudioSettingsSlider
function EditorAudioSettingsOverlayService:getUnitSlider(key, labelPrefix, value)
	return {
		key = key,
		label = ("%s %0.2f"):format(labelPrefix, value),
		value = value,
		min = 0,
		max = 1,
		step = 0.01,
	}
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param input rizu.editor.EditorAudioSettingsOverlayInput
function EditorAudioSettingsOverlayService:handleInput(context, input)
	local audio = context:getAudioSettings()
	for key, value in pairs(input.volumes) do
		if audio.volumeType ~= "linear" then
			value = decibel.lf_to_f(value)
		end
		self:setVolume(context, key, value)
	end
	self:setAudioOffset(context, input.audioOffsetMilliseconds / 1000)
	self:setWaveformOffset(context, input.waveformOffsetMilliseconds / 1000)
	self:setWaveformOpacity(context, input.waveformOpacity)
	self:setWaveformScale(context, input.waveformScale)
end

---@param context rizu.editor.EditorAudioSettingsOverlayContext
---@param key string
---@param value number
function EditorAudioSettingsOverlayService:setVolume(context, key, value)
	context:getAudioSettings().volume[key] = clampVolume(value)
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
