local Screen = require("gui.Screen")
local Colors = require("ui.Colors")
local Background = require("ui.screens.music_player.Background")
local Spectrum = require("ui.screens.music_player.Spectrum")
local ProgressBar = require("ui.screens.music_player.ProgressBar")
local Label = require("ui.views.Label")
local Rectangle = require("ui.views.Rectangle")

---@class ui.screens.music_player.MusicPlayer : gui.Screen
---@operator call: ui.screens.music_player.MusicPlayer
---@field ui ui.UserInterface
---@field title_label ui.views.Label
---@field artist_label ui.views.Label
local MusicPlayer = Screen + {}

---@param ui ui.UserInterface
function MusicPlayer:new(ui)
	Screen.new(self)
	self.ui = ui
	local preview_model = ui.game.previewModel
	preview_model:setFFTSize(Spectrum.fft_size)

	self.background = self.root:add(Background(ui.game.backgroundModel, preview_model, Spectrum.fft_size)):anchorFill(0, 0, 0, 0)
	self.root:add(Rectangle({0.035, 0.025, 0.06, 0.62})):anchorFill(0, 0, 0, 0)
	self.root:add(Spectrum(preview_model)):anchorFill(100, 210, 100, 270)

	self.title_label = self.root:add(Label({
		font_name = "cjk_bold",
		font_size = 48,
		text = "No song selected",
		align = "center",
	}))
	self.title_label:setAlignment(0.5, 0.1)
	self.title_label:setPivot(0.5, 0.5)

	self.artist_label = self.root:add(Label({
		font_name = "cjk_bold",
		font_size = 24,
		text = "",
		color = Colors.text_muted,
		align = "center",
	}))
	self.artist_label:setAlignment(0.5, 0.17)
	self.artist_label:setPivot(0.5, 0.5)

	self.root:add(ProgressBar(preview_model)):anchorFill(120, 900, 120, 115)

	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "escape" then
			self.ui:setScreen(self.ui.main_menu, true)
			return true
		elseif event.key == "left" then
			preview_model:setPosition(preview_model:getTime() - 5)
			return true
		elseif event.key == "right" then
			preview_model:setPosition(preview_model:getTime() + 5)
			return true
		end
	end

	self.root:setOpacity(0)
end

---@param chartview rizu.library.LocatedChartview?
function MusicPlayer:bind(chartview)
	if not chartview then
		self.title_label:setText("No song selected")
		self.artist_label:setText("")
		return
	end
	self.title_label:setText(chartview.title and chartview.title ~= "" and chartview.title or "Unknown title")
	self.artist_label:setText(chartview.artist and chartview.artist ~= "" and chartview.artist or "Unknown artist")
end

function MusicPlayer:enter()
	local chart_selector = self.ui.game.chartSelector
	chart_selector:onChanged(self)
	self:bind(chart_selector.chartview)
	chart_selector:notifyChartviewChanged()
	self.root:fadeIn(0.35, "OutCubic")
end

function MusicPlayer:exit()
	self.ui.game.chartSelector:offChanged(self)
	Screen.exit(self)
	self.root:fadeOut(0.25, "OutQuart")
	return true
end

---@param event rizu.select.Event|{name: string, [integer]: any}
function MusicPlayer:receive(event)
	if event.type == "chartview_changed" then
		self:bind(event.chartview)
	end
end

return MusicPlayer
