local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Sounds = require("ui.Sounds")
local Resources = require("ui.Resources")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")
local Spectrum = require("ui.screens.music_player.Spectrum")
local StripProgress = require("ui.screens.main_menu_v2.StripProgress")
local BgaRenderer = require("ui.views.BgaRenderer")
local AvatarShader = require("ui.views.AvatarShader")

local lg = love.graphics

local WIDTH, HEIGHT = 520, 92
local PADDING = 14
local BARS = 48
local BARS_HEIGHT = 44
-- Dims the background so the text reads on any image.
local SCRIM_ALPHA = 0.6
local PAN_PERIOD = 40 -- seconds for the background to go down and back up
local SHADOW_OFFSET = 2
local SHADOW_ALPHA = 0.8
local PROGRESS_HEIGHT = 3 -- the resting line, buttons and text stay above it
local BUTTONS_RIGHT = 8
local COVER_TINT = {0x2D / 255, 0x28 / 255, 0x3E / 255, 1}

---Bottom left of the main menu: what the preview plays, its background and a spectrum, and
---previous, pause and next. Next picks a random song, previous goes back to the one before.
---@class ui.screens.main_menu_v2.MusicStrip : gui.View
---@operator call: ui.screens.main_menu_v2.MusicStrip
---@field ui ui.UserInterface
---@field pause_button ui.screens.song_select_v2.HeaderButton
---@field buttons_x number where the buttons start, the text ends before it
---@field title string cut to the room left
---@field artist string cut to the room left by the time
---@field chart rizu.api.Chart?
---@field progress ui.screens.main_menu_v2.StripProgress
---@field unsubscribe fun()?
---@field time number
---@field bga_renderer ui.views.BgaRenderer
---@field cover_shader love.Shader?
local MusicStrip = View + {}

MusicStrip.WIDTH = WIDTH

---@param ui ui.UserInterface
function MusicStrip:new(ui)
	View.new(self)
	self.ui = ui
	self.title = ""
	self.artist = ""
	self.bga_renderer = BgaRenderer()
	self.time = 0
	self.handles_mouse_input = true
	self:setSize(WIDTH, HEIGHT)
	local sprites = Resources.sprites
	local charts, media = ui.api.charts, ui.api.media
	media:setSpectrumSize(Spectrum.fft_size)
	local spectrum = self:add(Spectrum(media, BARS, 3, 0.3))
	-- Square white bars added onto the image glow instead of covering it.
	spectrum.radius, spectrum.color, spectrum.blend_mode = 0, Colors.text, "add"
	spectrum:setPosition(0, HEIGHT - PROGRESS_HEIGHT - BARS_HEIGHT):setSize(WIDTH, BARS_HEIGHT)
	local next_button = self:add(HeaderButton(sprites.icon_chevron_right, function() charts:selectRandomSet() end))
	self.pause_button = self:add(HeaderButton(sprites.icon_pause, function() media:togglePreview() end))
	local previous_button = self:add(HeaderButton(sprites.icon_chevron_left, function() charts:undoRandomSet() end))
	local progress = self:add(StripProgress(media))
	self.progress = progress
	progress:setPosition(0, HEIGHT - StripProgress.HEIGHT):setSize(WIDTH, StripProgress.HEIGHT)
	local x = WIDTH - BUTTONS_RIGHT
	for _, button in ipairs({next_button, self.pause_button, previous_button}) do
		local width, height = button:getAuthoredSize() -- width is only resolved by the layout pass
		x = x - width
		button:setPosition(x, math.floor((HEIGHT - PROGRESS_HEIGHT - height) / 2))
	end
	self.buttons_x = x
end

function MusicStrip:load()
	local charts = self.ui.api.charts
	self.unsubscribe = charts:on("selection_changed", function(chart) self:bind(chart) end)
	self:bind(charts:getSelectedChart())
end

function MusicStrip:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end

---@param chart rizu.api.Chart?
function MusicStrip:bind(chart)
	local localization = self.ui.localization
	self.chart = chart
	local width = self.buttons_x - self:getTextX() - PADDING
	local title, artist = localization:get("music_player.no_song"), ""
	if chart then
		title = chart.title and chart.title ~= "" and chart.title or localization:get("music_player.unknown_title")
		artist = chart.artist and chart.artist ~= "" and chart.artist or localization:get("music_player.unknown_artist")
	end
	local small = Resources.getFont("cjk_bold", 14)
	self.title = ChartCarousel.fitText(Resources.getFont("cjk_bold", 18), title, width)
	self.artist = ChartCarousel.fitText(small, artist, width)
end

---@private
---@return number
function MusicStrip:getTextX() return PADDING end

---@param e gui.MouseClickEvent
function MusicStrip:onMouseClick(e)
	if e.button ~= 1 then return end
	Sounds.play("click")
	self.ui:setScreen(self.ui.music_player, true)
	return true
end

---@param inputs gui.Inputs
function MusicStrip:onHandleInputs(inputs)
	self.progress.expanded = self:isPointerOver(inputs.mouse_x, inputs.mouse_y)
end

---@param dt number
function MusicStrip:update(dt)
	self.time = self.time + dt
	self.pause_button.icon = self.ui.api.media:isPaused() and Resources.sprites.icon_play or Resources.sprites.icon_pause
end

---@private
function MusicStrip:drawBackground()
	Painter.setColorTable(COVER_TINT)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	local images, alpha = self.ui.api.media:getBackgroundImages()
	-- The background is cut to the panel: an avatar's rounded clip without the rounding.
	local shader = self.cover_shader or AvatarShader.new()
	self.cover_shader = shader
	AvatarShader.setRect(shader, 0, 0, WIDTH, HEIGHT, 0)
	lg.setShader(shader)
	for i, image in ipairs(images) do
		Painter.setColorRgb(1, 1, 1, i == 2 and alpha or 1)
		local w, h = image:getDimensions()
		local scale = math.max(WIDTH / w, HEIGHT / h)
		-- Pans over the part of the image that does not fit, so it never shows an edge.
		local slack = math.max(h * scale - HEIGHT, 0) / 2
		local pan = math.sin(self.time * 2 * math.pi / PAN_PERIOD) * slack
		lg.draw(image, (WIDTH - w * scale) / 2, (HEIGHT - h * scale) / 2 + pan, 0, scale)
	end
	-- Some charts have only a background animation. It is cut to the panel like the images.
	local animation, time = self.ui.api.media:getBackgroundAnimation()
	if animation then
		Painter.setColorRgb(1, 1, 1, 1)
		self.bga_renderer:draw(animation, time, WIDTH, HEIGHT)
	end
	lg.setShader()
	Painter.setColorRgb(COVER_TINT[1], COVER_TINT[2], COVER_TINT[3], SCRIM_ALPHA)
	lg.rectangle("fill", 0, 0, self.width, self.height)
end

function MusicStrip:draw()
	Painter.snapToPixel()
	self:drawBackground()

	local title_font, small = Resources.getFont("cjk_bold", 18), Resources.getFont("cjk_bold", 14)
	local text_x = self:getTextX()
	local text_y = math.floor((HEIGHT - PROGRESS_HEIGHT - title_font:getHeight() - small:getHeight()) / 2)
	local artist_y = text_y + title_font:getHeight()
	Painter.setColorRgb(0, 0, 0, SHADOW_ALPHA)
	lg.setFont(title_font)
	lg.print(self.title, text_x + SHADOW_OFFSET, text_y + SHADOW_OFFSET)
	lg.setFont(small)
	lg.print(self.artist, text_x + SHADOW_OFFSET, artist_y + SHADOW_OFFSET)
	Painter.setColorTable(Colors.text)
	lg.setFont(title_font)
	lg.print(self.title, text_x, text_y)
	Painter.setColorTable(Colors.muted)
	lg.setFont(small)
	lg.print(self.artist, text_x, artist_y)
end

return MusicStrip
