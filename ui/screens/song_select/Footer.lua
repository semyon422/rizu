local View = require("gui.View")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Panel = require("ui.views.Panel")
local FooterButton = require("ui.screens.song_select.FooterButton")
local MusicSpeedControl = require("ui.screens.song_select.MusicSpeedControl")

---@class ui.screens.song_select.Footer : gui.View
---@operator call: ui.screens.song_select.Footer
---@field back_button ui.screens.song_select.FooterButton
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

	local back_button = FooterButton({
		width = 154,
		height = HEIGHT,
		color = Colors.danger,
		text = ui.localization:get("song_select.back"),
		icon = Resources.sprites.icon_undo_2,
		large = true,
		padding_x = 17,
		on_click = function() ui:setScreen(ui.main_menu, true) end,
	})
	self.back_button = back_button

	local mods_button = FooterButton({
		height = 46,
		color = Colors.success,
		text = ui.localization:get("song_select.mods"),
		icon = Resources.sprites.icon_puzzle,
		badge = "0",
		gradient = Resources.sprites.song_select_loadout_success,
		hover_gradient = Resources.sprites.song_select_loadout_success_hover,
		active_gradient = Resources.sprites.song_select_loadout_success_active,
		active_hover_gradient = Resources.sprites.song_select_loadout_success_active_hover,
		padding_x = 17,
		on_click = function() ui.modal_manager:attachModifiers() end,
	})
	self.mods_button = mods_button
	local mutators_button = FooterButton({
		height = 46,
		color = Colors.magenta,
		text = ui.localization:get("song_select.mutators"),
		icon = Resources.sprites.icon_zap,
		badge = "0",
		gradient = Resources.sprites.song_select_loadout_magenta,
		hover_gradient = Resources.sprites.song_select_loadout_magenta_hover,
		active_gradient = Resources.sprites.song_select_loadout_magenta_active,
		active_hover_gradient = Resources.sprites.song_select_loadout_magenta_active_hover,
		padding_x = 17,
		on_click = function() ui.modal_manager:attachChartMutators() end,
	})
	self.mutators_button = mutators_button
	local inputs_button = FooterButton({
		height = 46,
		color = Colors.purple,
		text = ui.localization:get("song_select.inputs"),
		icon = Resources.sprites.icon_keyboard,
		gradient = Resources.sprites.song_select_loadout_purple,
		hover_gradient = Resources.sprites.song_select_loadout_purple_hover,
		padding_x = 17,
		on_click = function() ui.modal_manager:attachInput() end,
	})
	self.inputs_button = inputs_button
	local skins_button = FooterButton({
		height = 46,
		color = Colors.blue,
		text = ui.localization:get("song_select.skins"),
		icon = Resources.sprites.icon_paintbrush,
		gradient = Resources.sprites.song_select_loadout_blue,
		hover_gradient = Resources.sprites.song_select_loadout_blue_hover,
		padding_x = 17,
		on_click = function() ui.modal_manager:attachNoteSkins() end,
	})
	self.skins_button = skins_button

	local play_button = FooterButton({
		width = 154,
		height = HEIGHT,
		color = Colors.success,
		text = ui.localization:get("song_select.play"),
		icon = Resources.sprites.icon_play,
		large = true,
		icon_after = true,
		padding_x = 17,
		on_click = function()
			if game.chartSelector:chartExists() then
				ui:setScreen(ui.chart_loading, true)
			end
		end,
	})
	local music_speed = MusicSpeedControl(game.timeRateModel, game.modifierSelectModel)
	self.music_speed = music_speed
	self.play_button = play_button

	self:add(back_button)
	self:add(mods_button)
	self:add(mutators_button)
	self:add(inputs_button)
	self:add(skins_button)
	self:add(music_speed)
	self:add(play_button)
	self:updateState()
end

function Footer:layoutButtons()
	-- We need to say: this is stupid, and we should get a Flexbox container already.
	local back_width = self.back_button:getPreferredWidth()
	self.back_button:anchorFixed(0, 0, back_width, HEIGHT)

	local x = back_width + 14
	for _, button in ipairs({
		self.mods_button,
		self.mutators_button,
		self.inputs_button,
		self.skins_button,
	}) do
		local width = button:getPreferredWidth()
		button:anchorFixed(x, 9, width, 46)
		x = x + width + 6
	end

	local play_width = self.play_button:getPreferredWidth()
	self.play_button:anchorFixed(0, 0, play_width, HEIGHT):setAlignmentX(1)
	self.music_speed:anchorFixed(0, 0, 148, HEIGHT)
		:setAlignmentX(1)
		:addPosition(-(8 + play_width), 0)
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
	self:layoutButtons()
end

return Footer
