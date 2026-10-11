local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Label = require("ui.views.Label")
local IconTextButton = require("ui.views.IconTextButton")

-- Layout follows result_design/select.html (1920x1080 logical).
local HEIGHT = IconTextButton.HEIGHT
local BUTTON_GAP = 12
local OPTION_GAP = 10
local RATE_GAP = 28
local RATE_WIDTH = 140

---@class ui.screens.song_select_v2.Footer : gui.View
---@operator call: ui.screens.song_select_v2.Footer
---@field ui ui.UserInterface
---@field mods_button ui.views.IconTextButton
---@field mutators_button ui.views.IconTextButton
---@field inputs_button ui.views.IconTextButton
---@field skins_button ui.views.IconTextButton
---@field back_button ui.views.IconTextButton
---@field play_button ui.views.IconTextButton
---@field rate ui.views.Label
local Footer = View + {}

Footer.HEIGHT = HEIGHT

---@param ui ui.UserInterface
function Footer:new(ui)
	View.new(self)
	self.ui = ui
	local localization = ui.localization

	self.back_button = self:add(IconTextButton({
		text = localization:get("song_select.back"),
		icon = Resources.sprites.icon_undo_2,
		variant = "danger",
		font_size = 18,
		padding_left = 24,
		padding_right = 30,
		on_click = function() ui:setScreen(ui.main_menu, true) end,
	}))

	local options = self:add(FlowContainer({direction = "row", gap = OPTION_GAP}))
	self.options = options
	self.mods_button = options:add(IconTextButton({
		text = localization:get("song_select.mods"),
		icon = Resources.sprites.icon_puzzle,
		icon_color = Colors.grade_a,
		badge = "0",
		on_click = function() ui.modal_manager:attachModifiers() end,
	}))
	self.mutators_button = options:add(IconTextButton({
		text = localization:get("song_select.mutators"),
		icon = Resources.sprites.icon_zap,
		icon_color = Colors.grade_c,
		badge = "0",
		on_click = function() ui.modal_manager:attachChartMutators() end,
	}))
	self.inputs_button = options:add(IconTextButton({
		text = localization:get("song_select.inputs"),
		icon = Resources.sprites.icon_keyboard,
		icon_color = Colors.grade_b,
		on_click = function() ui.modal_manager:attachInput() end,
	}))
	self.skins_button = options:add(IconTextButton({
		text = localization:get("song_select.skins"),
		icon = Resources.sprites.icon_paintbrush,
		icon_color = Colors.grade_x,
		on_click = function() ui.modal_manager:attachNoteSkins() end,
	}))
	options:fitContent()
	options:setPosition(self.back_button:getPreferredWidth() + BUTTON_GAP, 0)

	self.play_button = self:add(IconTextButton({
		text = localization:get("song_select.play"),
		icon = Resources.sprites.icon_play,
		icon_after = true,
		variant = "success",
		font_size = 18,
		gap = 14,
		padding_left = 44,
		padding_right = 34,
		on_click = function()
			if ui.game.chartSelector:chartExists() then
				ui:loadSelectedChart(false, false, true)
			end
		end,
	}))
	self.play_button:setAlignmentX(1)

	local rate = self:add(View())
	rate:anchorFixed(0, 0, RATE_WIDTH, HEIGHT):setAlignmentX(1):addPosition(-(self.play_button:getPreferredWidth() + RATE_GAP), 0)
	rate.handles_mouse_input = true
	rate.onScroll = function(_, e)
		ui.game.timeRateModel:increase(e.direction_y > 0 and 1 or -1)
		ui.game.modifierSelectModel:change()
		return true
	end
	rate:add(Label({font_name = "medium", font_size = 13, color = Colors.muted, text = "RATE"}))
		:setAlignment(1, 0)
	self.rate = rate:add(Label({font_name = "bold", font_size = 34, color = Colors.grade_a}))
	self.rate:setAlignment(1, 1)

	self:updateState()
end

function Footer:updateState()
	local game = self.ui.game
	local replay_base = game.replayBase
	self.mods_button:setBadge(tostring((replay_base.const and 1 or 0) + (replay_base.tap_only and 1 or 0)))
	self.mutators_button:setBadge(tostring(#game.modifierSelectModel.replayBase.modifiers))
	self.options:fitContent()

	local chart_exists = game.chartSelector:chartExists()
	self.mods_button:setEnabled(chart_exists)
	self.mutators_button:setEnabled(chart_exists)
	self.inputs_button:setEnabled(chart_exists)
	self.skins_button:setEnabled(chart_exists)
	self.play_button:setEnabled(chart_exists)

	local value = game.timeRateModel:get()
	if replay_base.rate_type == "exp" then
		self.rate:setText(value > 0 and ("+%.0f"):format(value) or ("%.0f"):format(value))
	else
		self.rate:setText(("%.2fx"):format(value))
	end
end

return Footer
