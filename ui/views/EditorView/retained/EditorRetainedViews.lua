local EditorFooterView = require("ui.views.EditorView.retained.EditorFooterView")
local EditorOnsetsDistView = require("ui.views.EditorView.retained.EditorOnsetsDistView")
local EditorOnsetsView = require("ui.views.EditorView.retained.EditorOnsetsView")
local EditorOverlayView = require("ui.views.EditorView.retained.EditorOverlayView")
local EditorWaveformView = require("ui.views.EditorView.retained.EditorWaveformView")

---@param screen table
---@return gui.View[]
return function(screen)
	return {
		EditorWaveformView(screen),
		EditorOnsetsView(screen),
		EditorOnsetsDistView(screen),
		EditorFooterView(screen),
		EditorOverlayView(screen),
	}
end
