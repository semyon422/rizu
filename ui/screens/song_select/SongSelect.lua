local Screen = require("gui.Screen")
local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local UiActions = require("ui.UiActions")

local lg = love.graphics

---@class ui.screens.song_select.Panel : gui.View
---@operator call: ui.screens.song_select.Panel
---@field color gui.Color
---@field radius number
local Panel = View + {}

---@param color gui.Color
---@param radius number?
function Panel:new(color, radius)
	View.new(self)
	self.color = color
	self.radius = radius or 0
end

function Panel:draw()
	Painter.setColorTable(self.color)
	lg.rectangle("fill", 0, 0, self.width, self.height, self.radius, self.radius)
end

---@class ui.screens.song_select.SongSelect : gui.Screen
---@operator call: ui.screens.song_select.SongSelect
local SongSelect = Screen + {}

local HEADER_HEIGHT = 50
local TOOLBAR_HEIGHT = 72
local FOOTER_HEIGHT = 64

---@param ui ui.UserInterface
function SongSelect:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:add(Panel(Colors.background)):anchorFill(0, 0, 0, 0)

	local layout = self.root:add(TrackContainer({direction = "column"}))
	layout:anchorFill(0, 0, 0, 0)

	layout:add(Panel(Colors.panel), HEADER_HEIGHT)
	layout:add(Panel(Colors.panel), TOOLBAR_HEIGHT)

	local content = layout:add(TrackContainer({
		direction = "row",
		gap = 16,
		padding = {18, 14, 18, 14},
	}), "*")

	local left = content:add(TrackContainer({direction = "column", gap = 10}), "46%")
	left:add(Panel(Colors.panel, 5), "52%")
	left:add(Panel(Colors.panel, 7), "*")

	local right = content:add(TrackContainer({direction = "column", gap = 10}), "*")
	right:add(Panel(Colors.panel, 6), 78)
	right:add(Panel(Colors.panel, 7), "*")

	layout:add(Panel(Colors.panel), FOOTER_HEIGHT)

	self.root:setOpacity(0)
	self.root:setPivot(0.5, 0.5)
end

function SongSelect:enter()
	self.ui.command_registry:pushContext("select_commands", self.ui.select_commands)
	self.ui.command_registry:pushContext("ui_select_commands", self.ui.ui_select_commands)
	self.ui.command_registry:pushContext("location_commands", self.ui.location_commands)
	self.ui.command_registry:pushContext("database_commands", self.ui.database_commands)
	self.ui.command_registry:pushContext("note_skin_commands", self.ui.note_skin_commands)
	self.ui.command_registry:pushContext("play_config_commands", self.ui.play_config_commands)
	self.ui.command_registry:pushContext("online_commands", self.ui.online_commands)
	self.ui.command_registry:pushContext("package_commands", self.ui.package_commands)

	self.root:fadeIn(0.3, "OutCubic")
	self.root:scaleTo(1, 1, 0.3, "OutQuart")
end

function SongSelect:exit()
	self.ui.command_registry:popContext("select_commands")
	self.ui.command_registry:popContext("ui_select_commands")
	self.ui.command_registry:popContext("location_commands")
	self.ui.command_registry:popContext("database_commands")
	self.ui.command_registry:popContext("note_skin_commands")
	self.ui.command_registry:popContext("play_config_commands")
	self.ui.command_registry:popContext("online_commands")
	self.ui.command_registry:popContext("package_commands")

	Screen.exit(self)
	self.root:fadeOut(0.2, "OutQuad")
	self.root:scaleTo(1.01, 1.01, 0.3, "OutQuart")
	return true
end

-- ModalManager calls this after modifier dialogs close. The scaffold has no
-- modifier widgets to refresh yet.
function SongSelect:updateModifiers() end

---@param inputs gui.Inputs
function SongSelect:onHandleInputs(inputs)
	local game = self.ui.game
	if inputs:consumeActionJustPressed(UiActions.toggle_audio_preview) then
		game.previewModel:togglePause()
	elseif inputs:consumeActionJustPressed(UiActions.select_random) then
		game.chartSelector:scrollRandom()
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_decrease) then
		game.timeRateModel:increase(-1)
		game.modifierSelectModel:change()
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_increase) then
		game.timeRateModel:increase(1)
		game.modifierSelectModel:change()
	elseif inputs:consumeActionJustPressed(UiActions.refresh_song_select) then
		game.chartSelector:noDebounceRefresh()
	elseif inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	elseif game.chartSelector:chartExists() and inputs:consumeActionJustPressed(UiActions.accept) then
		self.ui:setScreen(self.ui.chart_loading, true)
	end
end

return SongSelect
