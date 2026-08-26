local View = require("gui.View")
local Colors = require("ui.Colors")
local Line = require("ui.views.Line")
local Panel = require("ui.views.Panel")

---@class ui.screens.song_select.ScoreListPanel : gui.View
---@operator call: ui.screens.song_select.ScoreListPanel
local ScoreListPanel = View + {}

function ScoreListPanel:new()
	View.new(self)
	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
	})):anchorFill(0, 0, 0, 0)

	local divider = self:add(Line({color = Colors.divider}))
	divider:anchorFixed(5, 54, 0, 0)
	divider:fillWidth(5, 5)
end

return ScoreListPanel
