local View = require("gui.View")
local Colors = require("ui.Colors")
local Line = require("ui.views.Line")
local Panel = require("ui.views.Panel")
local ScoreList = require("ui.screens.song_select.ScoreList")

---@class ui.screens.song_select.ScoreListPanel : gui.View
---@operator call: ui.screens.song_select.ScoreListPanel
---@field score_list ui.screens.song_select.ScoreList
local ScoreListPanel = View + {}

---@param score_selector rizu.select.ScoreSelector
---@param on_score_selected fun(index: integer)
function ScoreListPanel:new(score_selector, on_score_selected)
	View.new(self)
	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
	})):anchorFill(0, 0, 0, 0)
	self.score_list = self:add(ScoreList(score_selector, on_score_selected))
	self.score_list:anchorFill(5, 60, 5, 5)

	local divider = self:add(Line({color = Colors.divider}))
	divider:anchorFixed(5, 54, 0, 0)
	divider:fillWidth(5, 5)
end

return ScoreListPanel
