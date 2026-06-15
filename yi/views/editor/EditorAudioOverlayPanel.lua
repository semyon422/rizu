local class = require("class")

---@class yi.views.editor.EditorAudioOverlayPanel
---@operator call: yi.views.editor.EditorAudioOverlayPanel
local EditorAudioOverlayPanel = class()

---@param seconds number
---@return string
local function to_ms(seconds)
	return math.floor(seconds * 1000) .. "ms"
end

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param overlayContext rizu.editor.EditorViewContext
function EditorAudioOverlayPanel:draw(screen, panel, overlayContext)
	local audioState = screen.editorViewServices.audioOverlayService:getState(overlayContext)
	panel:text("playing sounds: " .. audioState.playingCount)
	panel:text("offsync: " .. to_ms(audioState.offsync))

	local audioSettingsOverlayService = screen.editorViewServices.audioSettingsOverlayService
	local audioSettingsState = audioSettingsOverlayService:getState(overlayContext)
	local a = audioSettingsState.audio
	local v = a.volume
	if a.volumeType == "linear" then
		audioSettingsOverlayService:setVolume(overlayContext, "master", panel:slider("v.master", v.master, 0, 1, 0.01, ("master %0.2f"):format(v.master)))
		audioSettingsOverlayService:setVolume(overlayContext, "music", panel:slider("v.music", v.music, 0, 1, 0.01, ("music %0.2f"):format(v.music)))
		audioSettingsOverlayService:setVolume(overlayContext, "keysounds", panel:slider("v.keysounds", v.keysounds, 0, 1, 0.01, ("keysounds %0.2f"):format(v.keysounds)))
		audioSettingsOverlayService:setVolume(overlayContext, "metronome", panel:slider("v.metronome", v.metronome, 0, 1, 0.01, ("metronome %0.2f"):format(v.metronome)))
	else
		audioSettingsOverlayService:setVolume(overlayContext, "master", panel:slider("v.master", v.master, -60, 0, 1, ("master %ddB"):format(v.master)))
		audioSettingsOverlayService:setVolume(overlayContext, "music", panel:slider("v.music", v.music, -60, 0, 1, ("music %ddB"):format(v.music)))
		audioSettingsOverlayService:setVolume(overlayContext, "keysounds", panel:slider("v.keysounds", v.keysounds, -60, 0, 1, ("keysounds %ddB"):format(v.keysounds)))
		audioSettingsOverlayService:setVolume(overlayContext, "metronome", panel:slider("v.metronome", v.metronome, -60, 0, 1, ("metronome %ddB"):format(v.metronome)))
	end

	panel:separator()
	panel:text("audio modes")
	panel:text("primary: " .. a.mode.primary)
	panel:text("secondary: " .. a.mode.secondary)

	panel:separator()
	local ed = audioSettingsState.editor
	audioSettingsOverlayService:setAudioOffset(overlayContext, panel:slider("ed.audioOffset", ed.audioOffset * 1000, -200, 200, 1, ("main audio offset %dms"):format(ed.audioOffset * 1000)) / 1000)
	audioSettingsOverlayService:setWaveformOffset(overlayContext, panel:slider("ed.waveformOffset", ed.waveformOffset * 1000, -200, 200, 1, ("waveform offset %dms"):format(ed.waveformOffset * 1000)) / 1000)

	panel:separator()
	panel:text("waveform")
	local wf = audioSettingsState.waveform
	audioSettingsOverlayService:setWaveformOpacity(overlayContext, panel:slider("wf.opacity", wf.opacity, 0, 1, 0.01, ("opacity %0.2f"):format(wf.opacity)))
	audioSettingsOverlayService:setWaveformScale(overlayContext, panel:slider("wf.scale", wf.scale, 0, 1, 0.01, ("scale %0.2f"):format(wf.scale)))

	panel:separator()
	if panel:button("set as preview", "set this moment as a preview") then
		screen.editorViewServices.overlayActionService:setPreviewTimeToSession(overlayContext)
	end
end

return EditorAudioOverlayPanel
