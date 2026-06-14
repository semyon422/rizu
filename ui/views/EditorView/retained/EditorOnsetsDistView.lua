local LegacyDrawView = require("ui.views.EditorView.retained.LegacyDrawView")
local OnsetsDistView = require("ui.views.EditorView.OnsetsDistView")

---@class ui.EditorOnsetsDistView: ui.EditorLegacyDrawView
---@operator call: ui.EditorOnsetsDistView
local EditorOnsetsDistView = LegacyDrawView + {}

---@param screen table
function EditorOnsetsDistView:new(screen)
	LegacyDrawView.new(self, screen, OnsetsDistView)
end

return EditorOnsetsDistView
