local EditorFooterView = require("yi.views.editor.EditorFooterView")
local EditorForegroundView = require("yi.views.editor.EditorForegroundView")
local EditorOnsetsDistView = require("yi.views.editor.EditorOnsetsDistView")
local EditorOnsetsView = require("yi.views.editor.EditorOnsetsView")
local EditorOverlayView = require("yi.views.editor.EditorOverlayView")
local EditorPlayfieldView = require("yi.views.editor.EditorPlayfieldView")
local EditorSequenceView = require("yi.views.editor.EditorSequenceView")
local EditorSnapGridView = require("yi.views.editor.EditorSnapGridView")
local EditorWaveformView = require("yi.views.editor.EditorWaveformView")

---@param screen table
---@return gui.View[]
return function(screen)
	return {
		EditorSequenceView(screen),
		EditorPlayfieldView(screen),
		EditorSnapGridView(screen),
		EditorWaveformView(screen),
		EditorOnsetsView(screen),
		EditorOnsetsDistView(screen),
		EditorFooterView(screen),
		EditorOverlayView(screen),
		EditorForegroundView(screen),
	}
end
