local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Colors = require("ui.Colors")
local Panel = require("ui.views.Panel")

---@class ui.screens.song_select.LibraryToolbar : gui.View
---@operator call: ui.screens.song_select.LibraryToolbar
local LibraryToolbar = View + {}

function LibraryToolbar:new()
	View.new(self)

	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
		lines = {bottom = true},
	})):anchorFill(0, 0, 0, 0)

	local controls = self:add(TrackContainer({
		direction = "row",
		gap = 8,
		padding = {18, 10, 18, 10},
	}))
	controls:anchorFill(0, 0, 0, 0)
	controls:add(Panel({color = Colors.surface}), 240)
	controls:add(Panel({color = Colors.surface}), 150)
	controls:add(Panel({color = Colors.surface}), 225)
	controls:add(Panel({color = Colors.surface}), "*")
end

return LibraryToolbar
