local LegacyDrawView = require("ui.views.EditorView.retained.LegacyDrawView")
local OnsetsView = require("ui.views.EditorView.OnsetsView")

---@class ui.EditorOnsetsView: ui.EditorLegacyDrawView
---@operator call: ui.EditorOnsetsView
local EditorOnsetsView = LegacyDrawView + {}

---@param screen table
function EditorOnsetsView:new(screen)
	LegacyDrawView.new(self, screen, OnsetsView)
end

return EditorOnsetsView
