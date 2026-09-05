local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Panel = require("ui.views.Panel")
local FooterButton = require("ui.screens.song_select.FooterButton")
local MusicSpeedControl = require("ui.screens.song_select.MusicSpeedControl")

---@class ui.screens.song_select.Footer : gui.View
---@operator call: ui.screens.song_select.Footer
---@field mods_button ui.screens.song_select.FooterButton
---@field mutators_button ui.screens.song_select.FooterButton
---@field inputs_button ui.screens.song_select.FooterButton
---@field skins_button ui.screens.song_select.FooterButton
---@field play_button ui.screens.song_select.FooterButton
local Footer = View + {}

local HEIGHT = 64

---@param ui ui.UserInterface
function Footer:new(ui)
	View.new(self)
	self.ui = ui
	local game = ui.game

	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
		lines = {top = true},
	})):anchorFill(0, 0, 0, 0)

	local layout = self:add(TrackContainer({direction = "row"}))
	layout:anchorFill(0, 0, 0, 0)
	layout:add(FooterButton({
		width = 154,
		height = HEIGHT,
		color = Colors.danger,
		text = "BACK",
		icon = Resources.sprites.icon_undo_2,
		large = true,
		on_click = function() ui:setScreen(ui.main_menu, true) end,
	}), 154)

	local loadout = layout:add(TrackContainer({
		direction = "row",
		gap = 6,
		padding = {14, 9, 0, 9},
	}), "*")
	self.mods_button = loadout:add(FooterButton({
		width = 112,
		height = 46,
		color = Colors.success,
		text = "MODS",
		icon = Resources.sprites.icon_puzzle,
		badge = "0",
		on_click = function() ui.modal_manager:attachModifiers() end,
	}), 112)
	self.mutators_button = loadout:add(FooterButton({
		width = 135,
		height = 46,
		color = Colors.magenta,
		text = "MUTATORS",
		icon = Resources.sprites.icon_zap,
		badge = "0",
		on_click = function() ui.modal_manager:attachChartMutators() end,
	}), 135)
	self.inputs_button = loadout:add(FooterButton({
		width = 110,
		height = 46,
		color = Colors.purple,
		text = "INPUTS",
		icon = Resources.sprites.icon_keyboard,
		on_click = function() ui.modal_manager:attachInput() end,
	}), 110)
	self.skins_button = loadout:add(FooterButton({
		width = 105,
		height = 46,
		color = Colors.blue,
		text = "SKINS",
		icon = Resources.sprites.icon_paintbrush,
	}), 105)

	local play_controls = layout:add(TrackContainer({direction = "row", gap = 8}), 310)
	self.music_speed = play_controls:add(MusicSpeedControl(game.timeRateModel, game.modifierSelectModel), 148)
	self.play_button = play_controls:add(FooterButton({
		width = 154,
		height = HEIGHT,
		color = Colors.success,
		text = "PLAY",
		icon = Resources.sprites.icon_play,
		large = true,
		icon_after = true,
		on_click = function()
			if game.chartSelector:chartExists() then
				ui:setScreen(ui.chart_loading, true)
			end
		end,
	}), 154)

	self:updateState()
end

function Footer:updateState()
	local game = self.ui.game
	local replay_base = game.replayBase
	local modifier_count = (replay_base.const and 1 or 0) + (replay_base.tap_only and 1 or 0)
	self.mods_button:setBadge(tostring(modifier_count))
	self.mods_button:setActive(modifier_count > 0)
	local mutator_count = #game.modifierSelectModel.replayBase.modifiers
	self.mutators_button:setBadge(tostring(mutator_count))
	self.mutators_button:setActive(mutator_count > 0)
	local chart_exists = game.chartSelector:chartExists()
	self.mods_button:setEnabled(chart_exists)
	self.mutators_button:setEnabled(chart_exists)
	self.inputs_button:setEnabled(chart_exists)
	self.skins_button:setEnabled(chart_exists)
	self.play_button:setEnabled(chart_exists)
end

return Footer
