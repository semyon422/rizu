local LegacyDrawView = require("ui.views.EditorView.retained.LegacyDrawView")
local WaveformView = require("ui.views.EditorView.WaveformView")

---@class ui.EditorWaveformView: ui.EditorLegacyDrawView
---@operator call: ui.EditorWaveformView
local EditorWaveformView = LegacyDrawView + {}

---@param screen table
function EditorWaveformView:new(screen)
	LegacyDrawView.new(self, screen, WaveformView)
end

return EditorWaveformView
