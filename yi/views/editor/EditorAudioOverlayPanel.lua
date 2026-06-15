local class = require("class")

---@class yi.views.editor.EditorAudioOverlayPanel
---@operator call: yi.views.editor.EditorAudioOverlayPanel
local EditorAudioOverlayPanel = class()

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param overlayContext rizu.editor.EditorViewContext
function EditorAudioOverlayPanel:draw(screen, panel, overlayContext)
	local audioState = screen.editorViewServices.audioOverlayService:getState(overlayContext)
	panel:text(audioState.playingCountLabel)
	panel:text(audioState.offsyncLabel)

	local audioSettingsOverlayService = screen.editorViewServices.audioSettingsOverlayService
	local audioSettingsState = audioSettingsOverlayService:getState(overlayContext)

	---@type {[string]: number}
	local volumes = {}
	for _, slider in ipairs(audioSettingsState.volumeSliders) do
		volumes[slider.key] = panel:slider("v." .. slider.key, slider.value, slider.min, slider.max, slider.step, slider.label)
	end

	panel:separator()
	panel:text("audio modes")
	panel:text(audioSettingsState.primaryModeLabel)
	panel:text(audioSettingsState.secondaryModeLabel)

	panel:separator()
	local audioOffsetSlider = audioSettingsState.audioOffsetSlider
	local audioOffsetMilliseconds = panel:slider(
		audioOffsetSlider.key,
		audioOffsetSlider.value,
		audioOffsetSlider.min,
		audioOffsetSlider.max,
		audioOffsetSlider.step,
		audioOffsetSlider.label
	)
	local waveformOffsetSlider = audioSettingsState.waveformOffsetSlider
	local waveformOffsetMilliseconds = panel:slider(
		waveformOffsetSlider.key,
		waveformOffsetSlider.value,
		waveformOffsetSlider.min,
		waveformOffsetSlider.max,
		waveformOffsetSlider.step,
		waveformOffsetSlider.label
	)

	panel:separator()
	panel:text("waveform")
	local waveformOpacitySlider = audioSettingsState.waveformOpacitySlider
	local waveformOpacity = panel:slider(
		waveformOpacitySlider.key,
		waveformOpacitySlider.value,
		waveformOpacitySlider.min,
		waveformOpacitySlider.max,
		waveformOpacitySlider.step,
		waveformOpacitySlider.label
	)
	local waveformScaleSlider = audioSettingsState.waveformScaleSlider
	local waveformScale = panel:slider(
		waveformScaleSlider.key,
		waveformScaleSlider.value,
		waveformScaleSlider.min,
		waveformScaleSlider.max,
		waveformScaleSlider.step,
		waveformScaleSlider.label
	)

	audioSettingsOverlayService:handleInput(overlayContext, {
		volumes = volumes,
		audioOffsetMilliseconds = audioOffsetMilliseconds,
		waveformOffsetMilliseconds = waveformOffsetMilliseconds,
		waveformOpacity = waveformOpacity,
		waveformScale = waveformScale,
	})

	panel:separator()
	if panel:button("set as preview", "set this moment as a preview") then
		screen.editorViewServices.overlayActionService:setPreviewTimeToSession(overlayContext)
	end
end

return EditorAudioOverlayPanel
