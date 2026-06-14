local LegacyDrawView = require("ui.views.EditorView.retained.LegacyDrawView")
local EditorViewOverlay = require("ui.views.EditorView.EditorViewOverlay")

---@class ui.EditorOverlayView: ui.EditorLegacyDrawView
---@operator call: ui.EditorOverlayView
local EditorOverlayView = LegacyDrawView + {}

---@param screen table
function EditorOverlayView:new(screen)
	LegacyDrawView.new(self, screen, EditorViewOverlay)
end

return EditorOverlayView
