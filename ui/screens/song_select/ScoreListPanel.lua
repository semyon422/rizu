local View = require("gui.View")
local NineSlice = require("gui.NineSlice")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Line = require("ui.views.Line")
local ScoreList = require("ui.screens.song_select.ScoreList")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select.ScoreListPanel : gui.View
---@operator call: ui.screens.song_select.ScoreListPanel
---@field score_list ui.screens.song_select.ScoreList
local ScoreListPanel = View + {}

---@param score_selector rizu.select.ScoreSelector
---@param on_score_selected fun(index: integer)
---@param localization ui.localization.Localization
function ScoreListPanel:new(score_selector, on_score_selected, localization)
	View.new(self)
	self:add(NineSlice(Resources.nine_slices.song_select_panel, nil, true)):anchorFill(0, 0, 0, 0)
	self.score_list = self:add(ScoreList(score_selector, on_score_selected, localization))
	self.score_list:anchorFill(5, 60, 5, 5)

	self.score_source_switcher = self:add(SegmentedControl({
		label = "",
		options = {"local", "online"},
		value = score_selector.settings:getChoice(Settings.keys.select.score_source),
		compact = true,
		format = function(source)
			return localization:get("song_select.score_source_" .. source)
		end,
		on_change = function(source)
			score_selector.settings:setChoice(Settings.keys.select.score_source, source)
			score_selector:pullScore()
		end,
	}))
	self.score_source_switcher:setAlignmentX(1):addPosition(-12, 8)

	local divider = self:add(Line({color = Colors.divider}))
	divider:anchorFixed(5, 54, 0, 0)
	divider:fillWidth(5, 5)
end

return ScoreListPanel
