local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local TrackContainer = require("gui.layout.TrackContainer")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Panel = require("ui.views.Panel")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Line = require("ui.views.Line")
local PlayerInfo = require("ui.views.PlayerInfo")
local SessionInfo = require("ui.screens.song_select.SessionInfo")
local HeaderButton = require("ui.screens.song_select.HeaderButton")

---@class ui.screens.song_select.SongSelectHeader : gui.View
---@operator call: ui.screens.song_select.SongSelectHeader
local SongSelectHeader = View + {}

---@param ui ui.UserInterface
function SongSelectHeader:new(ui)
	View.new(self)
	self:add(Panel({color = Colors.panel})):anchorFill(0, 0, 0, 0)

	local brand = self:add(FlowContainer({direction = "row", gap = 10, align = 0.5}))
	local logo = brand:add(Image(Resources.sprites.rizu_logo, "fit"))
	logo:setSize(34, 34)
	brand:add(Label({font_name = "bold", font_size = 18, text = "RIZU"}))
	brand:fitContent()
	brand:anchorFixed(16, 0, brand.width, 50)

	local session_info = self:add(SessionInfo())
	session_info:setAlignment(0.5, 0.5)

	local actions = self:add(FlowContainer({direction = "row", align = 0.5}))
	actions:add(PlayerInfo("Username"))

	local dock = actions:add(View())
	dock:setSize(126, 50)
	local dock_color = {Colors.surface[1], Colors.surface[2], Colors.surface[3], 0.42}
	dock:add(Panel({color = dock_color})):anchorFill(0, 0, 0, 0)
	local separator = dock:add(Line({color = Colors.outline, direction = "vertical"}))
	separator:anchorFixed(0, 0, 0, 50)
	local buttons = dock:add(TrackContainer({direction = "row"}))
	buttons:anchorFill(0, 0, 0, 0)
	buttons:add(HeaderButton(Resources.sprites.icon_gear, function()
		ui.modal_manager:attachConfig()
	end), 42)
	buttons:add(HeaderButton(Resources.sprites.icon_folder, function()
		ui:setScreen(ui.locations, true)
	end), 42)
	buttons:add(HeaderButton(Resources.sprites.icon_terminal, function()
		ui.modal_manager:attachPalette()
	end), 42)
	actions:fitContent()
	actions:setAlignmentX(1)
end

return SongSelectHeader
