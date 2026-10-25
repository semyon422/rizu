local Screen = require("gui.Screen")
local View = require("gui.View")
local CompositeView = require("gui.CompositeView")
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
local ScoreSourceToggle = require("ui.screens.song_select_v2.ScoreSourceToggle")
local Settings = require("rizu.config.Settings")
local UiConfig = require("ui.UiConfig")
local ScoreList = require("ui.screens.result_v2.ScoreList")
local UiActions = require("ui.UiActions")

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
---@field leaderboard_title ui.views.Label The score system of the accuracies in the list.
---@field footer ui.screens.song_select_v2.Footer
---@field library_toolbar ui.screens.song_select_v2.LibraryToolbar
---@field backdrop gui.View Background, blur and scrim; also drawn by chart loading
---@field content gui.CompositeView Everything above the backdrop
---@field unsubscribes fun()[]
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

local ZOOM_SCALE = 1.08
local ZOOM_ROTATION = math.rad(-2)

---Rotates the finished content canvas, following the zoom. The view itself stays unrotated:
---clipped views such as the carousel cannot be composed under a rotated parent.
---@param content gui.CompositeView
local function tiltContent(content)
	local x, y = content.width / 2, content.height / 2
	love.graphics.translate(x, y)
	love.graphics.rotate(ZOOM_ROTATION * (content.scale_x - 1) / (ZOOM_SCALE - 1))
	love.graphics.translate(-x, -y)
end

---@param ui ui.UserInterface
function SongSelectV2:new(ui)
	Screen.new(self)
	self.ui = ui

	-- The backdrop and the content fade separately: chart loading shows the same backdrop.
	-- One layer: fading the blur and the scrim on their own lets the blur show through brighter.
	self.backdrop = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)
	self.backdrop:add(Panel({color = Colors.background})):anchorFill(0, 0, 0, 0)
	self.blurred_background = self.backdrop:add(BlurredBackground(ui.api.media))
	self.blurred_background:anchorFill(0, 0, 0, 0)
	self.scrim = self.backdrop:add(Scrim())
	self.scrim:anchorFill(0, 0, 0, 0)
	self.content = self.root:add(CompositeView())
	self.content:anchorFill(0, 0, 0, 0):setPivot(0.5, 0.5)
	-- Follows the setting live, since the config modal opens over this screen.
	self.root:setUpdate(function()
		local visible = ui.api.settings:getBoolean(Settings.keys.select.blurred_background)
		self.blurred_background:setVisible(visible)
		self.scrim:setVisible(visible)
	end)

	self.chartview_formatter = ChartviewFormatter(ui.api.charts:getSelectedChart(), ui.api.settings)
	self.selected_song_panel = SelectedSongPanel(ui.api.media, ui.localization)
	local function setBrightness(brightness)
		self.blurred_background.brightness = brightness
		self.selected_song_panel.chart_preview.brightness = brightness
	end
	setBrightness(ui.config:getNumber(UiConfig.keys.select_background_brightness))
	ui.config:subscribeNumber(UiConfig.keys.select_background_brightness, setBrightness)
	self.chart_browser = ChartBrowser(ui, ui.api.charts, ui.api.settings, ui.localization, function()
		self.library_toolbar.search:setText("")
	end)

	-- Same place as on the old screen: top of the left column, between the header, toolbar and footer rows.
	local layout = self.content:add(TrackContainer({direction = "column"}))
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

	self.content:add(Header(ui)):fillWidth(0, 0):setHeight(Header.HEIGHT)

	local popup_container = PopupContainer()
	self.library_toolbar = self.content:add(LibraryToolbar(ui, popup_container))
	self.library_toolbar:fillWidth(EDGE, EDGE):setHeight(TOOLBAR_HEIGHT):addPosition(0, TOOLBAR_TOP)

	self.footer = Footer(ui)
	-- Invisible corner areas under the buttons, so hitting the very corner of the screen still works.
	local back_hit = self.content:add(CornerHit(function() self.footer.back_button.on_click() end))
	back_hit:setSize(EDGE + self.footer.back_button:getPreferredWidth(), Footer.HEIGHT + FOOTER_BOTTOM + 12)
		:setAlignment(0, 1)
	local play_hit = self.content:add(CornerHit(function() self.footer.play_button:onMouseClick({button = 1}) end))
	play_hit:setSize(EDGE + self.footer.play_button:getPreferredWidth(), Footer.HEIGHT + FOOTER_BOTTOM + 12)
		:setAlignment(1, 1)
	self.content:add(self.footer)
	self.footer:fillWidth(EDGE, EDGE):setHeight(Footer.HEIGHT):setAlignmentY(1):addPosition(0, -FOOTER_BOTTOM)
	self.content:add(popup_container)

	self.backdrop:setOpacity(0)
	self.content:setOpacity(0)
end

---@private
---@return gui.View
function SongSelectV2:createScores()
	local ui = self.ui
	local scores_api = ui.api.scores
	local scores = TrackContainer({direction = "column", gap = SCORES_GAP})

	local head = scores:add(View(), SCORES_HEADER_HEIGHT)
	self.leaderboard_title = head:add(Label({font_name = "bold", font_size = 20, color = Colors.muted}))
	self.leaderboard_title:setAlignment(0, 0.5)
	head:add(ScoreSourceToggle(scores_api, ui.localization)):setHeight(SCORES_HEADER_HEIGHT):setAlignment(1, 0.5)

	self.score_list = scores:add(ScoreList(scores_api, ui.localization, ui.api.online), "*")
	self.score_list:setEmptySpriteEnabled(true)
	self.score_list:setAnimated(true)
	self.score_list:setOnSelect(function(index) self:openScore(index) end)
	return scores
end

---@param index integer
function SongSelectV2:openScore(index)
	local scores = self.ui.api.scores
	scores:select(index)
	if not scores:getSelected() then
		return
	end
	scores:loadSelectedResult(function(ok)
		self.ui:setScreen(ok and self.ui.result or self)
	end)
end

function SongSelectV2:enter()
	local api = self.ui.api
	-- A play stops the previews.
	api.media:startPreview()
	local function updateFooter() self.footer:updateState() end
	self.unsubscribes = {
		api.charts:on("selection_changed", function(chart)
			self:bindChartview(chart)
			updateFooter()
		end),
		api.charts:on("can_play_changed", updateFooter),
		-- Another score system was picked for the list.
		api.scores:on("scores_changed", function()
			self:updateLeaderboardTitle(api.charts:getSelectedChart())
		end),
		api.scores:on("scores_changed", function(loading)
			self.score_list:setLoading(loading)
			-- Rows are replaced once loading finishes; the old ones fade out meanwhile.
			if loading then
				self.score_list:fadeOutItems()
			else
				self.score_list:reload()
			end
		end),
		api.play:on("mods_changed", updateFooter),
		api.play:on("rate_changed", function()
			local chart = api.charts:getSelectedChart()
			if chart then
				self.chartview_formatter:setTimeRate(api.play:getRate())
				self.chart_browser.chart_info:bind(self.chartview_formatter)
			end
			updateFooter()
		end),
	}
	-- Score loading may have started before this screen subscribed.
	api.scores:refresh()
	self.score_list:reload()
	self.library_toolbar:updateCollections()
	self.footer:updateState()
	self:bindChartview(api.charts:getSelectedChart())
	self.backdrop:fadeIn(0.3, "OutCubic")
	-- Undoes zoomOut(), which ends while the screen is already hidden.
	self.content:clearTransforms():setScale(1, 1)
	rawset(self.content, "drawUnderlay", nil)
	self.content:fadeIn(0.3, "OutCubic")
end

function SongSelectV2:exit()
	for _, unsubscribe in ipairs(self.unsubscribes) do
		unsubscribe()
	end
	self.unsubscribes = {}
	Screen.exit(self)
	self.content:fadeOut(0.2, "OutQuad")
	-- The backdrop stays until the next screen covers it; two half-faded screens would show black through.
	self.backdrop:delay(0.2):fadeOut(0.2, "OutQuad")
	return true
end

---Replaces the content fade of exit() on the way into chart loading: the content also flies
---towards the viewer. Ends together with the backdrop fade.
function SongSelectV2:zoomOut()
	self.content:fadeOut(0.3, "OutQuad")
	self.content:scaleTo(ZOOM_SCALE, ZOOM_SCALE, 0.4, "OutCubic")
	rawset(self.content, "drawUnderlay", tiltContent)
end

---@private
---@param chartview rizu.api.Chart?
function SongSelectV2:bindChartview(chartview)
	self.chartview_formatter:setChartview(chartview)
	self.chartview_formatter:setTimeRate(self.ui.api.play:getRate())
	if chartview then
		self.selected_song_panel:bind(self.chartview_formatter)
		self.chart_browser.chart_info:bind(self.chartview_formatter)
	end
	self:updateLeaderboardTitle(chartview)
end

---@private
---@param chartview rizu.api.Chart?
function SongSelectV2:updateLeaderboardTitle(chartview)
	local scoring = self.ui.api.scores:getAccuracySystem(chartview)
	self.leaderboard_title:setText(scoring and scoring:getName() or self.ui.localization:get("song_select.leaderboard"))
end

function SongSelectV2:updateModifiers()
	self.footer:updateState()
end

---@param inputs gui.Inputs
function SongSelectV2:onHandleInputs(inputs)
	local charts = self.ui.api.charts
	if inputs:consumeActionJustPressed(UiActions.up) then
		charts:moveSet(-1)
	elseif inputs:consumeActionJustPressed(UiActions.down) then
		charts:moveSet(1)
	elseif inputs:consumeActionJustPressed(UiActions.left) then
		charts:moveChart(-1)
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		charts:moveChart(1)
	elseif inputs:consumeActionJustPressed(UiActions.select_random) then
		charts:selectRandomSet()
	elseif inputs:consumeActionJustPressed(UiActions.select_random_undo) then
		charts:undoRandomSet()
	elseif not inputs.keyboard_focus and inputs:consumeActionJustPressed(UiActions.focus_search) then
		-- The "/" text input was dispatched before this, so it does not reach the search.
		inputs:setKeyboardFocus(self.library_toolbar.search, {control = false, shift = false, alt = false, super = false})
	elseif inputs:consumeActionJustPressed(UiActions.open_modifiers) then
		self.ui.modal_manager:attachModifiers()
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_decrease) then
		self.ui.api.play:changeRate(-1)
	elseif inputs:consumeActionJustPressed(UiActions.select_time_rate_increase) then
		self.ui.api.play:changeRate(1)
	elseif inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	elseif charts:canPlaySelectedChart() and inputs:consumeActionJustPressed(UiActions.accept) then
		self.ui:loadSelectedChart(false, false, true)
	elseif charts:canPlaySelectedChart() and inputs:consumeActionJustPressed(UiActions.select_autoplay) then
		self.ui:loadSelectedChart(true, false, true)
	end
end

return SongSelectV2
