local Screen = require("gui.Screen")
local Colors = require("ui.Colors")
local Background = require("ui.screens.music_player.Background")
local Spectrum = require("ui.screens.music_player.Spectrum")
local ProgressBar = require("ui.screens.music_player.ProgressBar")
local Label = require("ui.views.Label")
local Rectangle = require("ui.views.Rectangle")
local UiActions = require("ui.UiActions")
local BgaPreview = require("ui.views.BgaPreview")

---@class ui.screens.music_player.MusicPlayer : gui.Screen
---@operator call: ui.screens.music_player.MusicPlayer
---@field ui ui.UserInterface
---@field title_label ui.views.Label
---@field artist_label ui.views.Label
---@field private unsubscribe fun()
local MusicPlayer = Screen + {}

---@param ui ui.UserInterface
function MusicPlayer:new(ui)
	Screen.new(self)
	self.ui = ui
	local media = ui.api.media
	media:setSpectrumSize(Spectrum.fft_size)

	self.background = self.root:add(Background(media, Spectrum.fft_size)):anchorFill(0, 0, 0, 0)
	self.root:add(BgaPreview(media)):anchorFill(0, 0, 0, 0)
	self.root:add(Rectangle({0.035, 0.025, 0.06, 0.62})):anchorFill(0, 0, 0, 0)
	self.root:add(Spectrum(media)):anchorFill(100, 210, 100, 270)

	self.title_label = self.root:add(Label({
		font_name = "cjk_bold",
		font_size = 48,
		text = ui.localization:get("music_player.no_song"),
	}))
	self.title_label:setAlignment(0.5, 0.1)
	self.title_label:setPivot(0.5, 0.5)

	self.artist_label = self.root:add(Label({
		font_name = "cjk_bold",
		font_size = 24,
		text = "",
		color = Colors.muted,
	}))
	self.artist_label:setAlignment(0.5, 0.17)
	self.artist_label:setPivot(0.5, 0.5)

	self.root:add(ProgressBar(media)):anchorFill(120, 900, 120, 115)

	self.root:setOpacity(0)
end

---@param inputs gui.Inputs
function MusicPlayer:onHandleInputs(inputs)
	local media = self.ui.api.media
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	elseif inputs:consumeActionJustPressed(UiActions.left) then
		media:setPreviewTime((media:getPreviewTime()) - 5)
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		media:setPreviewTime((media:getPreviewTime()) + 5)
	end
end

---@param chartview rizu.api.Chart?
function MusicPlayer:bind(chartview)
	if not chartview then
		self.title_label:setText(self.ui.localization:get("music_player.no_song"))
		self.artist_label:setText("")
		return
	end
	self.title_label:setText(chartview.title and chartview.title ~= "" and chartview.title or self.ui.localization:get("music_player.unknown_title"))
	self.artist_label:setText(chartview.artist and chartview.artist ~= "" and chartview.artist or self.ui.localization:get("music_player.unknown_artist"))
end

function MusicPlayer:enter()
	local charts = self.ui.api.charts
	self.unsubscribe = charts:on("selection_changed", function(chart) self:bind(chart) end)
	self:bind(charts:getSelectedChart())
	charts:announceSelection()
	self.root:fadeIn(0.35, "OutCubic")
end

function MusicPlayer:exit()
	self.unsubscribe()
	Screen.exit(self)
	self.root:fadeOut(0.25, "OutQuart")
	return true
end

return MusicPlayer
