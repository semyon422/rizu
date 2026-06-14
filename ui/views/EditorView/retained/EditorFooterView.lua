local LegacyDrawView = require("ui.views.EditorView.retained.LegacyDrawView")
local Footer = require("ui.views.EditorView.Footer")

---@class ui.EditorFooterView: ui.EditorLegacyDrawView
---@operator call: ui.EditorFooterView
local EditorFooterView = LegacyDrawView + {}

---@param screen table
function EditorFooterView:new(screen)
	LegacyDrawView.new(self, screen, Footer)
end

return EditorFooterView
