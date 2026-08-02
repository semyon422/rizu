local Screen = require("gui.Screen")
local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local FlowContainer = require("gui.layout.FlowContainer")
local StackContainer = require("gui.layout.StackContainer")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local BackgroundPanel = require("ui.screens.song_select.BackgroundPanel")
local ScoreList = require("ui.screens.song_select.ScoreList")
local ChartSets = require("ui.screens.song_select.ChartSets")
local ChartGrid = require("ui.screens.song_select.ChartGrid")
local InfoPanel = require("ui.screens.song_select.InfoPanel")
local DifficultyPanel = require("ui.screens.song_select.DifficultyPanel")
local GameplayModifiers = require("ui.screens.song_select.GameplayModifiers")
local TimeRate = require("ui.screens.song_select.TimeRate")
local Footer = require("ui.screens.song_select.Footer")
local FooterButton = require("ui.screens.song_select.FooterButton")
local FooterCell = require("ui.screens.song_select.FooterCell")
local PlayerInfo = require("ui.views.PlayerInfo")
local SessionInfo = require("ui.views.SessionInfo")
local Label = require("ui.views.Label")
local Rectangle = require("ui.views.Rectangle")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ReplayBaseFormatter = require("ui.formatters.ReplayBaseFormatter")

---@class ui.screens.song_select.SongSelect : gui.Screen
---@operator call: ui.screens.song_select.SongSelect
local SongSelect = Screen + {}

local HEADER_HEIGHT = 50
local FOOTER_HEIGHT = 80

---@param ui ui.UserInterface
function SongSelect:new(ui)
	Screen.new(self)
	self.ui = ui

	self.chartview_formatter = ChartviewFormatter(
		ui.game.chartSelector.chartview,
		ui.game.persistence.configModel.configs.settings
	)

	self.replay_base_formatter = ReplayBaseFormatter(
		ui.game.replayBase,
		ui.game.persistence.configModel.configs.settings
	)

	self.background_panel = BackgroundPanel(self.ui.game.backgroundModel, self.ui.game)
	self.score_list = ScoreList(self.ui.game.scoreSelector, function(index)
		self:openScore(index)
	end)
	self.chart_grid = ChartGrid(self.ui.game.chartSelector)
	self.chart_sets = ChartSets(
		self.ui.game.chartSelector,
		self.ui.game.persistence.configModel.configs.settings,
		function() end
	)
	self.difficulty_panel = DifficultyPanel()
	self.info_panel = InfoPanel()

	self.back_button = FooterButton(
		Colors.back_button,
		true,
		Colors.text,
		{
			icon = Resources.sprites.icon_chevron_left,
			text = "BACK",
		},
		function()
			self.ui:setScreen(self.ui.main_menu, true)
		end
	)

	self.play_button = FooterButton(
		Colors.play_button,
		true,
		Colors.text,
		{
			icon = Resources.sprites.icon_play,
			text = "PLAY",
			reverse = true,
		},
		function()
			if self.ui.game.chartSelector:chartExists() then
				self.ui:setScreen(self.ui.chart_loading, true)
			end
		end
	)

	self.mods_button = FooterButton(
		Colors.green,
		false,
		Colors.text,
		{
			icon = Resources.sprites.icon_puzzle,
			text = "MODS"
		}
	)

	self.skins_button = FooterButton(
		Colors.blue,
		false,
		Colors.text,
		{
			icon = Resources.sprites.icon_brush,
			text = "SKINS"
		}
	)

	self.footer_right = FlowContainer({
		direction = "row",
		align = 0.5,
		gap = 10,
	})

	self.player_info = PlayerInfo("Username", 1, 20.00, 95.05)
	self.session_info = SessionInfo()
	self.time_rate = TimeRate(self.ui.game.timeRateModel, self.ui.game.modifierSelectModel)
	self.gameplay_modifiers = GameplayModifiers()

	self.container = self.root:add(TrackContainer({direction = "column"}))
	self.container:anchorFill(0, 0, 0, 0)

	self:createContent()

	self.root:setOpacity(0)
	self.root:setPivot(0.5, 0.5)
	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "return" and self.ui.game.chartSelector:chartExists() then
			self.ui:setScreen(self.ui.chart_loading, true)
		end
	end
end

---@param index integer
function SongSelect:openScore(index)
	local game = self.ui.game
	game.scoreSelector:scrollScore(nil, index)
	game.resultController:replayNoteChartAsync("result", game.scoreSelector.chartplay)
	self.ui:setScreen(self.ui.result, true)
end

function SongSelect:enter()
	self.time_rate:updateText()

	local chart_selector = self.ui.game.chartSelector
	chart_selector:notifyChartviewChanged()
	chart_selector:onChanged(self)
	chart_selector.state:onChanged(self)
	chart_selector.stores[2]:onChanged(self)
	self.ui.game.scoreSelector:onChanged(self)

	local chartview = chart_selector.chartview
	if chartview then
		self:onChartviewUpdate(chartview)
		self:updateInfo()
	end

	self.root:fadeIn(0.3, "OutCubic")
	self.root:scaleTo(1, 1, 0.3, "OutQuart")
end

function SongSelect:exit()
	local chart_selector = self.ui.game.chartSelector
	chart_selector:offChanged(self)
	chart_selector.state:offChanged(self)
	chart_selector.stores[2]:offChanged(self)
	self.ui.game.scoreSelector:offChanged(self)

	Screen.exit(self)
	self.root:fadeOut(0.2, "OutQuad")
	self.root:scaleTo(1.01, 1.01, 0.3, "OutQuart")
	return true
end

function SongSelect:createContent()
	self.container:add(self:createHeader(), HEADER_HEIGHT)

	local body = self.container:add(TrackContainer({
		direction = "row",
		padding = {0, 43, 0, 0},
		align = 0.5,
	}), "*")

	body:add(View(), "*")
	body:add(self:createLeftColumn(), "44%")
	body:add(View(), "*")
	body:add(self:createRightColumn(), "46%")
	body:add(View(), "*")

	self.container:add(self:createFooter(), FOOTER_HEIGHT)
end

function SongSelect:createLeftColumn()
	local column = TrackContainer({
		direction = "column",
		gap = 10
	})
	column:add(self.background_panel, 469)
	column:add(self.score_list, 400)
	return column
end

function SongSelect:createRightColumn()
	local column = TrackContainer({
		direction = "column",
		gap = 10,
	})

	local heading = View()

	heading:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "Displaying the entire library",
		color = Colors.text_muted,
	})):setAlignment(0, 0.5)

	heading:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "No filters",
		color = Colors.text_muted,
	})):setAlignment(1, 0.5)

	column:add(heading, 28)
	column:add(Rectangle(Colors.panel), 44)
	column:add(self.chart_sets, 562)

	local info = column:add(TrackContainer({
		gap = 10,
		direction = "row",
	}), 80)

	info:add(self.difficulty_panel, 214) -- TODO: DifficultyPanel should be able to scale freely
	info:add(self.info_panel, "*")
	column:add(self.chart_grid, 136)
	return column
end

function SongSelect:createHeader()
	local header = Rectangle(Colors.panel)
	return header
end

function SongSelect:createFooter()
	local container = StackContainer({padding = {20, 0, 20, 0}, align_items_y = "center"})
	local footer = container:add(Footer())

	local left = footer:add(FlowContainer({direction = "row", align = 0.5, gap = 10}))
	left:add(self.back_button)
	left:add(self.mods_button)
	left:add(self.skins_button)
	left:fitContent()
	left:setAlignment(0, 1)

	footer:add(self.session_info):setAlignment(0.5, 0.5)

	footer:add(self.footer_right)
	self.gameplay_modifiers_cell = self.footer_right:add(FooterCell(self.gameplay_modifiers))
	self.time_rate_cell = self.footer_right:add(FooterCell(self.time_rate))
	self.footer_right:add(self.play_button)
	self.footer_right:fitContent()
	self.footer_right:setAlignment(1, 1)

	return container
end

---@param chartview rizu.library.LocatedChartview
function SongSelect:onChartviewUpdate(chartview)
	self.chartview_formatter:setChartview(chartview)
	self.chartview_formatter:setTimeRate(self.ui.game.timeRateModel:get())
	self.background_panel:bind(self.chartview_formatter)
	self.difficulty_panel:bind(self.chartview_formatter)
	self.info_panel:bind(self.chartview_formatter)
end

function SongSelect:updateInfo()
	self.replay_base_formatter:setReplayBase(self.ui.game.replayBase)

	self.score_list:reload()
	self.chart_grid:reloadItems()
	self.gameplay_modifiers:bind(self.replay_base_formatter)

	-- TODO: Make Right panel container as a separate view
	self.gameplay_modifiers_cell:fitContent()
	self.time_rate_cell:fitContent()
	self.footer_right:fitContent()
end

---@param event rizu.select.Event|{name: string, [integer]: any}
function SongSelect:receive(event)
	if event.type == "chartview_changed" and event.chartview and event.chartview.hash then
		self:onChartviewUpdate(event.chartview)
	end

	if event.type == "selected_set_changed" then
		self:updateInfo()
	elseif event.type == "score_items_changed" then
		self.score_list:reload()
	elseif event.type == "list_count_changed" or event.type == "list_item_loaded" then
		self.chart_grid:requestReloadItems()
	end

	self.background_panel:receive(event)
end

return SongSelect
