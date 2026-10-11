local Screen = require("gui.Screen")
local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Colors = require("ui.Colors")
local Panel = require("ui.views.Panel")
local BlurredBackground = require("ui.views.BlurredBackground")
local Scrim = require("ui.screens.song_select_v2.Scrim")
local Footer = require("ui.screens.song_select_v2.Footer")
local Header = require("ui.screens.song_select_v2.Header")
local LibraryToolbar = require("ui.screens.song_select_v2.LibraryToolbar")
local PopupContainer = require("ui.views.PopupContainer")
local ChartBrowser = require("ui.screens.song_select_v2.ChartBrowser")
local SelectedSongPanel = require("ui.screens.song_select_v2.SelectedSongPanel")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local Label = require("ui.views.Label")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local Settings = require("rizu.config.Settings")
local ScoreList = require("ui.screens.result_v2.ScoreList")
local UiActions = require("ui.UiActions")
local thread = require("thread")

---@class ui.screens.song_select_v2.CornerHit : gui.View
---@field on_click fun()
local CornerHit = View + {}

---@param on_click fun()
function CornerHit:new(on_click)
	View.new(self)
	self.on_click = on_click
	self.handles_mouse_input = true
end

---@param e gui.MouseClickEvent
function CornerHit:onMouseClick(e)
	if e.button == 1 then
		self.on_click()
		return true
	end
end

---@class ui.screens.song_select_v2.SongSelectV2 : gui.Screen
---@operator call: ui.screens.song_select_v2.SongSelectV2
---@field ui ui.UserInterface
---@field chartview_formatter ui.formatters.ChartviewFormatter
---@field selected_song_panel ui.screens.song_select_v2.SelectedSongPanel
---@field chart_browser ui.screens.song_select_v2.ChartBrowser
---@field score_list ui.screens.result_v2.ScoreList
---@field footer ui.screens.song_select_v2.Footer
---@field library_toolbar ui.screens.song_select_v2.LibraryToolbar
local SongSelectV2 = Screen + {}

-- Layout follows result_design/select.html (1920x1080 logical).
local EDGE = 24
local FOOTER_BOTTOM = 12
local TOOLBAR_TOP = 66
local TOOLBAR_HEIGHT = 54
local SCORES_ROWS = 5
local SCORES_HEADER_HEIGHT = 36
local SCORES_GAP = 10
-- Extra room below the rows, taken from the selected song panel.
local SCORES_EXTRA_HEIGHT = 5

---@param ui ui.UserInterface
function SongSelectV2:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:add(Panel({color = Colors.background})):anchorFill(0, 0, 0, 0)
	self.root:add(BlurredBackground(ui.game.backgroundModel)):anchorFill(0, 0, 0, 0)
	self.root:add(Scrim()):anchorFill(0, 0, 0, 0)

	self.chartview_formatter = ChartviewFormatter(ui.game.chartSelector.chartview, ui.game.settings)
	self.selected_song_panel = SelectedSongPanel(ui.game.backgroundModel, ui.game, ui.localization)
	self.chart_browser = ChartBrowser(ui, ui.game.chartSelector, ui.game.settings, ui.tooltip, ui.localization, function()
		self.library_toolbar.search:setText("")
	end)

	-- Same place as on the old screen: top of the left column, between the header, toolbar and footer rows.
	local layout = self.root:add(TrackContainer({direction = "column"}))
	layout:anchorFill(0, 0, 0, 0)
	layout:add(View(), 122)
	local content = layout:add(TrackContainer({
		direction = "row",
		gap = 16,
		padding = {18, 14, 18, 14},
	}), "*")
	local left = content:add(TrackContainer({direction = "column", gap = 10}), "46%")
	left:add(self.selected_song_panel, "*")
	left:add(self:createScores(), SCORES_HEADER_HEIGHT + SCORES_GAP + ScoreList.getHeightForRows(SCORES_ROWS) + SCORES_EXTRA_HEIGHT)
	local right = content:add(TrackContainer({direction = "column", gap = 10}), "*")
	right:add(self.chart_browser, "*")
	layout:add(View(), Footer.HEIGHT + FOOTER_BOTTOM + 8)

	self.root:add(Header(ui)):fillWidth(0, 0):setHeight(Header.HEIGHT)

	local popup_container = PopupContainer()
	self.library_toolbar = self.root:add(LibraryToolbar(ui, popup_container))
	self.library_toolbar:fillWidth(EDGE, EDGE):setHeight(TOOLBAR_HEIGHT):addPosition(0, TOOLBAR_TOP)

	self.footer = Footer(ui)
	-- Invisible corner areas under the buttons, so hitting the very corner of the screen still works.
	local back_hit = self.root:add(CornerHit(function() self.footer.back_button.on_click() end))
	back_hit:setSize(EDGE + self.footer.back_button:getPreferredWidth(), Footer.HEIGHT + FOOTER_BOTTOM + 12)
		:setAlignment(0, 1)
	local play_hit = self.root:add(CornerHit(function() self.footer.play_button:onMouseClick({button = 1}) end))
	play_hit:setSize(EDGE + self.footer.play_button:getPreferredWidth(), Footer.HEIGHT + FOOTER_BOTTOM + 12)
		:setAlignment(1, 1)
	self.root:add(self.footer)
	self.footer:fillWidth(EDGE, EDGE):setHeight(Footer.HEIGHT):setAlignmentY(1):addPosition(0, -FOOTER_BOTTOM)
	self.root:add(popup_container)

	self.root:setOpacity(0)
end

---@private
---@return gui.View
function SongSelectV2:createScores()
	local ui = self.ui
	local score_selector = ui.game.scoreSelector
	local scores = TrackContainer({direction = "column", gap = SCORES_GAP})

	local head = scores:add(View(), SCORES_HEADER_HEIGHT)
	head:add(Label({
		font_name = "bold",
		font_size = 20,
		color = Colors.muted,
		text = "LEADERBOARD",
	})):setAlignment(0, 0.5)
	head:add(SegmentedControl({
		label = "",
		options = {"local", "online"},
		value = score_selector.settings:getChoice(Settings.keys.select.score_source),
		compact = true,
		format = function(source)
			return ui.localization:get("song_select.score_source_" .. source)
		end,
		on_change = function(source)
			score_selector.settings:setChoice(Settings.keys.select.score_source, source)
			score_selector:pullScore()
		end,
	})):setAlignment(1, 0.5)

	self.score_list = scores:add(ScoreList(score_selector, ui.localization, ui.game.online_client, ui.game.avatar_cache), "*")
	self.score_list:setEmptySpriteEnabled(true)
	self.score_list:setAnimated(true)
	self.score_list:setOnSelect(function(index) self:openScore(index) end)
	return scores
end

---@param index integer
function SongSelectV2:openScore(index)
	local game = self.ui.game
	game.scoreSelector:scrollScore(nil, index)
	local chartplay = game.scoreSelector.chartplay
	if not chartplay then
		return
	end
	thread.coro(function()
		local ok, err = pcall(function()
			game.resultController:replayNoteChartAsync("result", chartplay)
		end)
		if ok then
			self.ui:setScreen(self.ui.result)
		else
			print("failed to load score:", err)
			self.ui:setScreen(self)
		end
	end)()
end

function SongSelectV2:enter()
	local score_selector = self.ui.game.scoreSelector
	self.ui.game.chartSelector:onChanged(self)
	score_selector:onChanged(self)
	self.ui.game.timeRateModel:onChanged(self)
	self.ui.game.collectionSelector:onChanged(self)
	-- Score loading may have started before this screen subscribed.
	score_selector:pullScore()
	self.score_list:reload()
	self.library_toolbar:updateCollections()
	self.footer:updateState()
	self:bindChartview(self.ui.game.chartSelector.chartview)
	self.root:fadeIn(0.3, "OutCubic")
end

function SongSelectV2:exit()
	self.ui.game.chartSelector:offChanged(self)
	self.ui.game.scoreSelector:offChanged(self)
	self.ui.game.timeRateModel:offChanged(self)
	self.ui.game.collectionSelector:offChanged(self)
	Screen.exit(self)
	self.root:fadeOut(0.2, "OutQuad")
	return true
end

---@private
---@param chartview rizu.library.LocatedChartview?
function SongSelectV2:bindChartview(chartview)
	self.chartview_formatter:setChartview(chartview)
	self.chartview_formatter:setTimeRate(self.ui.game.replayBase.rate)
	if chartview and chartview.hash then
		self.selected_song_panel:bind(self.chartview_formatter)
		self.chart_browser.chart_info:bind(self.chartview_formatter)
	end
end

---@param event rizu.select.Event|{name: string, [integer]: any}
function SongSelectV2:receive(event)
	if event.type == "collection_selection_changed" then
		self.library_toolbar:updateCollections()
	end
	if event.type == "chartview_changed" then
		self:bindChartview(event.chartview)
	end
	-- Rows are replaced once loading finishes; the transient clear while loading is ignored.
	if event.type == "score_items_changed" then
		self.score_list:setLoading(event.loading and true or false)
		-- The old rows fade out while the new ones load.
		if event.loading then
			self.score_list:fadeOutItems()
		end
	end
	if event.type == "score_items_changed" and not event.loading then
		self.score_list:reload()
	end
	if event.type == "time_rate_changed" and self.ui.game.chartSelector.chartview.hash then
		self.chartview_formatter:setTimeRate(self.ui.game.replayBase.rate)
		self.chart_browser.chart_info:bind(self.chartview_formatter)
	end
	if event.type == "chartview_changed" or event.type == "chart_availability_changed"
		or event.type == "time_rate_changed"
	then
		self.footer:updateState()
	end
end

function SongSelectV2:updateModifiers()
	self.footer:updateState()
end

---@param inputs gui.Inputs
function SongSelectV2:onHandleInputs(inputs)
	local game = self.ui.game
	local chart_selector = game.chartSelector
	if inputs:consumeActionJustPressed(UiActions.up) then
		chart_selector:scrollLevel(1, -1)
	elseif inputs:consumeActionJustPressed(UiActions.down) then
		chart_selector:scrollLevel(1, 1)
	elseif inputs:consumeActionJustPressed(UiActions.left) then
		chart_selector:scrollLevel(2, -1)
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		chart_selector:scrollLevel(2, 1)
	elseif inputs:consumeActionJustPressed(UiActions.select_random) then
		chart_selector:scrollRandom()
	elseif inputs:consumeActionJustPressed(UiActions.open_modifiers) then
		self.ui.modal_manager:attachModifiers()
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_decrease) then
		game.timeRateModel:increase(-1)
		game.modifierSelectModel:change()
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_increase) then
		game.timeRateModel:increase(1)
		game.modifierSelectModel:change()
	elseif inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	elseif chart_selector:chartExists() and inputs:consumeActionJustPressed(UiActions.accept) then
		self.ui:loadSelectedChart(false, false, true)
	end
end

return SongSelectV2
