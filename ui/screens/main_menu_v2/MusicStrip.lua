local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")
local AvatarShader = require("ui.views.AvatarShader")

local lg = love.graphics

local WIDTH, HEIGHT = 520, 92
local PADDING = 14
local COVER_SIZE = 64
local PROGRESS_HEIGHT = 3
local BUTTONS_RIGHT = 8
local COVER_TINT = {0x2D / 255, 0x28 / 255, 0x3E / 255, 1}

---@param seconds number
---@return string
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

---Bottom left of the main menu: what the preview plays, its background as the cover, the time, and
---previous, pause and next. Next picks a random song, previous goes back to the one before.
---@class ui.screens.main_menu_v2.MusicStrip : gui.View
---@operator call: ui.screens.main_menu_v2.MusicStrip
---@field ui ui.UserInterface
---@field pause_button ui.screens.song_select_v2.HeaderButton
---@field buttons_x number where the buttons start, the text ends before it
---@field title string cut to the room left
---@field artist string cut to the room left by the time
---@field chart rizu.api.Chart?
---@field unsubscribe fun()?
---@field cover_shader love.Shader?
local MusicStrip = View + {}

MusicStrip.WIDTH = WIDTH

---@param ui ui.UserInterface
function MusicStrip:new(ui)
	View.new(self)
	self.ui = ui
	self.title = ""
	self.artist = ""
	self:setSize(WIDTH, HEIGHT)
	local sprites = Resources.sprites
	local charts, media = ui.api.charts, ui.api.media
	local next_button = self:add(HeaderButton(sprites.icon_chevron_right, function() charts:selectRandomSet() end))
	self.pause_button = self:add(HeaderButton(sprites.icon_pause, function() media:togglePreview() end))
	local previous_button = self:add(HeaderButton(sprites.icon_chevron_left, function() charts:undoRandomSet() end))
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
	local small = Resources.getFont("cjk_regular", 14)
	self.title = ChartCarousel.fitText(Resources.getFont("cjk_bold", 18), title, width)
	-- Leaves room for " · 00:00 / 00:00".
	self.artist = ChartCarousel.fitText(small, artist, width - small:getWidth(" · 00:00 / 00:00"))
end

---@private
---@return number
function MusicStrip:getTextX() return PADDING + COVER_SIZE + PADDING end

---@param dt number
function MusicStrip:update(dt)
	self.pause_button.icon = self.ui.api.media:isPaused() and Resources.sprites.icon_play or Resources.sprites.icon_pause
end

---@private
function MusicStrip:drawCover()
	local x, y = PADDING, math.floor((HEIGHT - PROGRESS_HEIGHT - COVER_SIZE) / 2)
	Painter.setColorTable(COVER_TINT)
	lg.rectangle("fill", x, y, COVER_SIZE, COVER_SIZE)
	local images, alpha = self.ui.api.media:getBackgroundImages()
	-- The background is cut to a square: an avatar's rounded clip without the rounding.
	local shader = self.cover_shader or AvatarShader.new()
	self.cover_shader = shader
	AvatarShader.setRect(shader, x, y, COVER_SIZE, COVER_SIZE, 0)
	lg.setShader(shader)
	for i, image in ipairs(images) do
		Painter.setColorRgb(1, 1, 1, i == 2 and alpha or 1)
		local w, h = image:getDimensions()
		local scale = math.max(COVER_SIZE / w, COVER_SIZE / h)
		lg.draw(image, x + (COVER_SIZE - w * scale) / 2, y + (COVER_SIZE - h * scale) / 2, 0, scale)
	end
	lg.setShader()
end

function MusicStrip:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	self:drawCover()

	local media = self.ui.api.media
	local time, start, finish = media:getPreviewTime()
	local position, duration = math.max(time - start, 0), math.max(finish - start, 0)

	local title_font, small = Resources.getFont("cjk_bold", 18), Resources.getFont("cjk_regular", 14)
	local text_x = self:getTextX()
	local text_y = math.floor((HEIGHT - PROGRESS_HEIGHT - title_font:getHeight() - small:getHeight()) / 2)
	Painter.setColorTable(Colors.text)
	lg.setFont(title_font)
	lg.print(self.title, text_x, text_y)
	Painter.setColorTable(Colors.muted)
	lg.setFont(small)
	local time_text = ("%s / %s"):format(formatTime(position), formatTime(duration))
	lg.print(self.artist ~= "" and self.artist .. " · " .. time_text or time_text, text_x, text_y + title_font:getHeight())

	Painter.setColorTable(Colors.surface)
	lg.rectangle("fill", 0, HEIGHT - PROGRESS_HEIGHT, self.width, PROGRESS_HEIGHT)
	Painter.setColorTable(Colors.success)
	local progress = duration > 0 and math.min(position / duration, 1) or 0
	lg.rectangle("fill", 0, HEIGHT - PROGRESS_HEIGHT, math.floor(self.width * progress), PROGRESS_HEIGHT)
end

return MusicStrip
