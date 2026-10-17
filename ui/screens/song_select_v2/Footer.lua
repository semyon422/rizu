local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local Resources = require("ui.Resources")
local Label = require("ui.views.Label")
local IconTextButton = require("ui.views.IconTextButton")
local ResultMutators = require("ui.screens.result_v2.ResultMutators")
local RateFormatter = require("ui.formatters.RateFormatter")

-- Layout follows result_design/select.html (1920x1080 logical).
local HEIGHT = IconTextButton.HEIGHT
local BUTTON_GAP = 12
local OPTION_GAP = 10
local RATE_GAP = 28
local RATE_WIDTH = 140
local MUTATORS_WIDTH = 420

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
---@field mutators ui.screens.result_v2.ResultMutators
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
			if ui.api.charts:canPlaySelectedChart() then
				ui:loadSelectedChart(false, false, true)
			end
		end,
	}))
	self.play_button:setAlignmentX(1)

	local rate = self:add(View())
	rate:anchorFixed(0, 0, RATE_WIDTH, HEIGHT):setAlignmentX(1):addPosition(-(self.play_button:getPreferredWidth() + RATE_GAP), 0)
	rate.handles_mouse_input = true
	rate.onScroll = function(_, e)
		ui.api.play:changeRate(e.direction_y > 0 and 1 or -1)
		return true
	end
	rate:add(Label({font_name = "medium", font_size = 13, color = Colors.muted, text = "RATE"}))
		:setAlignment(1, 0)
	self.rate = rate:add(Label({font_name = "bold", font_size = 34, color = {1, 1, 1, 1}}))
	self.rate:setAlignment(1, 1)

	self.mutators = self:add(ResultMutators(MUTATORS_WIDTH, {icon_size = HEIGHT, show_values = false, align_right = true}))
	self.mutators:anchorFixed(0, 0, MUTATORS_WIDTH, HEIGHT):setAlignmentX(1)
		:addPosition(-(self.play_button:getPreferredWidth() + RATE_GAP + RATE_WIDTH + RATE_GAP), 0)

	self:updateState()
end

function Footer:updateState()
	local play = self.ui.api.play
	self.mods_button:setBadge(tostring(play:getModCount()))
	self.mutators_button:setBadge(tostring(play:getMutatorCount()))
	self.options:fitContent()

	local chart_exists = self.ui.api.charts:canPlaySelectedChart()
	self.mods_button:setEnabled(chart_exists)
	self.mutators_button:setEnabled(chart_exists)
	self.inputs_button:setEnabled(chart_exists)
	self.skins_button:setEnabled(chart_exists)
	self.play_button:setEnabled(chart_exists)

	self.rate:setText(RateFormatter.format(play:getRateValue(), play:getRateType()))
	Color.rateToColor(play:getRate(), self.rate.color)
	self.mutators:bind(play:getMutators(), play)
end

return Footer
