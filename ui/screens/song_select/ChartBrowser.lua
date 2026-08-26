local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Colors = require("ui.Colors")
local Line = require("ui.views.Line")
local Panel = require("ui.views.Panel")
local ChartSets = require("ui.screens.song_select.ChartSets")

---@class ui.screens.song_select.ChartBrowser : gui.View
---@operator call: ui.screens.song_select.ChartBrowser
---@field chart_sets ui.screens.song_select.ChartSets
local ChartBrowser = View + {}

---@param chart_selector rizu.select.ChartSelector
---@param settings rizu.config.Config
function ChartBrowser:new(chart_selector, settings)
	View.new(self)

	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
	})):anchorFill(0, 0, 0, 0)

	local content = self:add(TrackContainer({
		direction = "column",
		padding = 6,
	}))
	content:anchorFill(0, 0, 0, 0)
	content:add(View(), 78)

	self.chart_sets = ChartSets(chart_selector, settings, function() end)
	content:add(self.chart_sets, "*")

	local divider = self:add(Line({color = Colors.divider}))
	divider:anchorFixed(6, 84, 0, 0)
	divider:fillWidth(6, 6)
end

return ChartBrowser
