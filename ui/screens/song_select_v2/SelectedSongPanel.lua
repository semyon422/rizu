local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local ProgressBar = require("ui.screens.music_player.ProgressBar")
local SpringValue = require("gui.anim.SpringValue")
local ChartPreviewView = require("ui.screens.song_select_v2.ChartPreviewView")
local math_util = require("math_util")

local lg = love.graphics

local CHART_NAME_GAP = 20

---@class ui.screens.song_select_v2.SelectedSongPanel.Details : gui.View
---@operator call: ui.screens.song_select_v2.SelectedSongPanel.Details
---@field panel ui.screens.song_select_v2.SelectedSongPanel
local Details = View + {}

---@param panel ui.screens.song_select_v2.SelectedSongPanel
function Details:new(panel)
	View.new(self)
	self.panel = panel
end

function Details:draw()
	local panel = self.panel
	Painter.setOpacity(panel.details_opacity:get())
	lg.setFont(panel.title_font)
	Painter.setColorRgb(0, 0, 0, 0.25)
	lg.print(panel.title, 22, 2)
	Painter.setColorTable(Colors.text)
	lg.print(panel.title, 20, 0)
	lg.setFont(panel.artist_font)
	Painter.setColorRgb(0, 0, 0, 0.25)
	lg.print(panel.artist, 22, panel.title_font:getHeight() + 2)
	Painter.setColorTable(Colors.accent)
	lg.print(panel.artist, 20, panel.title_font:getHeight())

	if panel.chart_name ~= "" then
		local x = 20 + panel.artist_font:getWidth(panel.artist) + CHART_NAME_GAP
		-- Share the artist's baseline, the fonts differ in size.
		local y = panel.title_font:getHeight()
			+ panel.artist_font:getBaseline() - panel.chart_name_font:getBaseline()
		lg.setFont(panel.chart_name_font)
		Painter.setColorRgb(0, 0, 0, 0.25)
		lg.print(panel.chart_name, x + 2, y + 2)
		Painter.setColorTable(Colors.text)
		lg.print(panel.chart_name, x, y)
	end
end

---@class ui.screens.song_select_v2.SelectedSongPanel.PauseButton : gui.View
---@operator call: ui.screens.song_select_v2.SelectedSongPanel.PauseButton
---@field is_paused boolean
local PauseButton = View + {}

---@param on_click function
function PauseButton:new(on_click)
	View.new(self)
	self.on_click = on_click
	self.handles_mouse_input = true
	self.is_paused = false
	self:setSize(38, 40)
	self:setOpacity(0)
	self:setPivot(0.5, 0.5)
end

function PauseButton:onMouseDown(e)
	self:scaleTo(1.3, 1.3, 0.1, "OutQuad")
	self.on_click()
end

function PauseButton:onMouseUp(e)
	self:scaleTo(1, 1, 0.1, "OutQuad")
end

function PauseButton:draw()
	if self.is_paused then
		Resources.sprites.icon_continue:draw()
	else
		Resources.sprites.icon_pause:draw()
	end
end

---@class ui.screens.song_select_v2.SelectedSongPanel : gui.View
---@operator call: ui.screens.song_select_v2.SelectedSongPanel
---@field chart_preview ui.screens.song_select_v2.ChartPreviewView
---@field details_container ui.screens.song_select_v2.SelectedSongPanel.Details
---@field progress_bar ui.screens.music_player.ProgressBar
---@field title_font love.Font
---@field artist_font love.Font
---@field chart_name_font love.Font
---@field title string
---@field artist string
---@field chart_name string
---@field details_opacity gui.anim.SpringValue
---@field details_reveal gui.anim.SpringValue
---@field details_hidden_offset number
local SelectedSongPanel = View + {}

local DETAILS_PADDING = 20
local PROGRESS_HEIGHT = 54
local PROGRESS_BOTTOM = 10
local DETAILS_BOTTOM_PADDING = 8
local DETAILS_GAP = 12
-- Downward offset while idle. Keep it low enough for the title and artist to remain visible.
local DETAILS_IDLE_Y = 56 + DETAILS_BOTTOM_PADDING

---@param media rizu.api.Media
---@param localization ui.localization.Localization
function SelectedSongPanel:new(media, localization)
	View.new(self)
	self.chart_preview = self:add(ChartPreviewView(media))
	self.chart_preview:anchorFill(0, 0, 0, 0)
	self.title_font = Resources.getFont("cjk_bold", 48)
	self.artist_font = Resources.getFont("cjk_bold", 24)
	self.chart_name_font = Resources.getFont("cjk_regular", 20)
	self.title = localization:get("song_select.title")
	self.artist = localization:get("song_select.artist")
	self.chart_name = ""
	self.details_opacity = SpringValue({
		value = 0,
		stiffness = 120,
		damping = 22,
	})
	self.details_reveal = SpringValue({
		value = 0,
		stiffness = 220,
		damping = 26,
	})
	self.details_hidden_offset = 0
	self.handles_mouse_input = true
	self:setClip(true)
	self.details_container = self:add(Details(self))
	self.progress_bar = self.details_container:add(ProgressBar(media))
	self.pause_button = self:add(PauseButton(function() media:togglePreview() end))
	self.pause_button:setAlignment(0.5, 0.5)
	self.media = media
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function SelectedSongPanel:onLayoutChanged(old_x, old_y, old_width, old_height)
	local title_height = self.title_font:getHeight()
	local artist_height = self.artist_font:getHeight()
	local details_height = title_height + artist_height + DETAILS_GAP
		+ PROGRESS_HEIGHT + DETAILS_BOTTOM_PADDING
	local details_y = self.height - details_height - PROGRESS_BOTTOM
	self.details_container:anchorFixed(0, details_y, self.width, details_height)
	self.progress_bar:anchorFixed(
		DETAILS_PADDING,
		title_height + artist_height + DETAILS_GAP,
		math.max(0, self.width - DETAILS_PADDING * 2),
		PROGRESS_HEIGHT
	)
	self.pause_button:setAlignment(0.5, 0.5)
	self.details_hidden_offset = DETAILS_IDLE_Y
	self.details_container:setOffset(0, self.details_hidden_offset * (1 - self.details_reveal:get()))
end

---@param dt number
function SelectedSongPanel:update(dt)
	self.details_opacity:update(dt)
	-- The pause button and progress bar take the mouse target from the panel while hovered.
	local hovered = self.mouse_over or self.pause_button.mouse_over or self.progress_bar.mouse_over
	self.details_reveal:set(hovered and 1 or 0):update(dt)
	self.pause_button:setOpacity(math_util.clamp(self.details_reveal:get(), 0, 1))
	self.pause_button.is_paused = self.media:isPaused()
	self.details_container:setOffset(0, self.details_hidden_offset * (1 - self.details_reveal:get()))
end

---@param cvf ui.formatters.ChartviewFormatter
function SelectedSongPanel:bind(cvf)
	self.details_opacity:snap(0):set(1)
	self.title = cvf:getTitle()
	self.artist = cvf:getArtist()
	self.chart_name = cvf:getName() or ""
	self.chart_preview:bind(cvf)
end

return SelectedSongPanel
