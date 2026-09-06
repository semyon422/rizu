local Screen = require("gui.Screen")
local TrackContainer = require("gui.layout.TrackContainer")
local Colors = require("ui.Colors")
local Panel = require("ui.views.Panel")
local PopupContainer = require("ui.views.PopupContainer")
local SongSelectHeader = require("ui.screens.song_select.SongSelectHeader")
local LibraryToolbar = require("ui.screens.song_select.LibraryToolbar")
local SelectedSongPanel = require("ui.screens.song_select.SelectedSongPanel")
local ScoreListPanel = require("ui.screens.song_select.ScoreListPanel")
local ChartBrowser = require("ui.screens.song_select.ChartBrowser")
local ChartSummary = require("ui.screens.song_select.ChartSummary")
local Footer = require("ui.screens.song_select.Footer")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local UiActions = require("ui.UiActions")

---@class ui.screens.song_select.SongSelect : gui.Screen
---@operator call: ui.screens.song_select.SongSelect
---@field selected_song_panel ui.screens.song_select.SelectedSongPanel
---@field score_list_panel ui.screens.song_select.ScoreListPanel
---@field chart_browser ui.screens.song_select.ChartBrowser
---@field chart_summary ui.screens.song_select.ChartSummary
---@field library_toolbar ui.screens.song_select.LibraryToolbar
---@field footer ui.screens.song_select.Footer
local thread = require("thread")

local SongSelect = Screen + {}

local HEADER_HEIGHT = 50
local TOOLBAR_HEIGHT = 72
local FOOTER_HEIGHT = 64

---@param ui ui.UserInterface
function SongSelect:new(ui)
	Screen.new(self)
	self.ui = ui
	self.chartview_formatter = ChartviewFormatter(
		ui.game.chartSelector.chartview,
		ui.game.settings
	)
	self.selected_song_panel = SelectedSongPanel(ui.game.backgroundModel, ui.game)
	self.score_list_panel = ScoreListPanel(ui.game.scoreSelector, function(index)
		self:openScore(index)
	end)
	self.chart_browser = ChartBrowser(ui.game.chartSelector, ui.game.settings)
	self.chart_summary = ChartSummary(self.chartview_formatter)
	self.popup_container = PopupContainer()

	self.root:add(Panel({color = Colors.background})):anchorFill(0, 0, 0, 0)

	local layout = self.root:add(TrackContainer({direction = "column"}))
	layout:anchorFill(0, 0, 0, 0)

	layout:add(SongSelectHeader(ui), HEADER_HEIGHT)
	self.library_toolbar = layout:add(LibraryToolbar(ui, self.popup_container), TOOLBAR_HEIGHT)

	local content = layout:add(TrackContainer({
		direction = "row",
		gap = 16,
		padding = {18, 14, 18, 14},
	}), "*")

	local left = content:add(TrackContainer({direction = "column", gap = 10}), "46%")
	left:add(self.selected_song_panel, "52%")
	left:add(self.score_list_panel, "*")

	local right = content:add(TrackContainer({direction = "column", gap = 10}), "*")
	right:add(self.chart_summary, 78)
	right:add(self.chart_browser, "*")

	self.footer = layout:add(Footer(ui), FOOTER_HEIGHT)
	self.root:add(self.popup_container)

	self.root:setOpacity(0)
	self.root:setPivot(0.5, 0.5)
end

---@param index integer
function SongSelect:openScore(index)
	local game = self.ui.game
	game.scoreSelector:scrollScore(nil, index)
	if game.scoreSelector.chartplay then
		thread.coro(function()
			game.resultController:replayNoteChartAsync("result", game.scoreSelector.chartplay)
		end)()
		self.ui:setScreen(self.ui.result)
	end
end

function SongSelect:enter()
	local chart_selector = self.ui.game.chartSelector
	chart_selector:onChanged(self)
	self.ui.game.scoreSelector:onChanged(self)
	self.ui.game.collectionSelector:onChanged(self)
	self.score_list_panel.score_list:reload()
	self.library_toolbar:updateCollections()
	self.footer:updateState()
	local chartview = chart_selector.chartview
	if chartview and chartview.hash then
		self.chartview_formatter:setChartview(chartview)
		self.chartview_formatter:setTimeRate(self.ui.game.replayBase.rate)
		self.selected_song_panel:bind(self.chartview_formatter)
		self.chart_summary:bind()
	end

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
	self.ui.game.chartSelector:offChanged(self)
	self.ui.game.scoreSelector:offChanged(self)
	self.ui.game.collectionSelector:offChanged(self)

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

---@param event rizu.select.Event|{name: string, [integer]: any}
function SongSelect:receive(event)
	if event.type == "collection_selection_changed" then
		self.library_toolbar:updateCollections()
	end
	if event.type == "chartview_changed" then
		self.chartview_formatter:setChartview(event.chartview)
		self.chartview_formatter:setTimeRate(self.ui.game.replayBase.rate)
		if event.chartview and event.chartview.hash then
			self.selected_song_panel:bind(self.chartview_formatter)
		end
		self.chart_summary:bind()
	end
	if event.type == "chartview_changed" then
		self.footer:updateState()
	end
	if event.type == "score_items_changed" then
		self.score_list_panel.score_list:reload()
	end
	self.selected_song_panel:receive(event)
end

function SongSelect:updateModifiers()
	self.footer:updateState()
end

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
		self.footer:updateState()
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_increase) then
		game.timeRateModel:increase(1)
		game.modifierSelectModel:change()
		self.footer:updateState()
	elseif inputs:consumeActionJustPressed(UiActions.refresh_song_select) then
		game.chartSelector:noDebounceRefresh()
	elseif inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	elseif game.chartSelector:chartExists() and inputs:consumeActionJustPressed(UiActions.accept) then
		self.ui:setScreen(self.ui.chart_loading, true)
	end
end

return SongSelect
