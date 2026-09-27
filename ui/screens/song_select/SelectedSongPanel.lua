local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local ProgressBar = require("ui.screens.music_player.ProgressBar")
local SpringValue = require("gui.anim.SpringValue")
local ChartPreviewView = require("ui.screens.song_select.ChartPreviewView")

local lg = love.graphics

---@class ui.screens.song_select.SelectedSongPanel.Details : gui.View
---@operator call: ui.screens.song_select.SelectedSongPanel.Details
---@field panel ui.screens.song_select.SelectedSongPanel
local Details = View + {}

---@param panel ui.screens.song_select.SelectedSongPanel
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
end

---@class ui.screens.song_select.SelectedSongPanel : gui.View
---@operator call: ui.screens.song_select.SelectedSongPanel
---@field chart_preview ui.screens.song_select.ChartPreviewView
---@field details_container ui.screens.song_select.SelectedSongPanel.Details
---@field progress_bar ui.screens.music_player.ProgressBar
---@field game sphere.GameController
---@field title_font love.Font
---@field artist_font love.Font
---@field title string
---@field artist string
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

---@param bg_model sphere.BackgroundModel
---@param game sphere.GameController
---@param localization ui.localization.Localization
function SelectedSongPanel:new(bg_model, game, localization)
	View.new(self)
	self.game = game
	self.chart_preview = self:add(ChartPreviewView(bg_model, game))
	self.chart_preview:anchorFill(0, 0, 0, 0)
	self.title_font = Resources.getFont("cjk_bold", 48)
	self.artist_font = Resources.getFont("cjk_bold", 24)
	self.title = localization:get("song_select.title")
	self.artist = localization:get("song_select.artist")
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
	self.progress_bar = self.details_container:add(ProgressBar(game.previewModel))
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
	self.details_hidden_offset = DETAILS_IDLE_Y
	self.details_container:setOffset(0, self.details_hidden_offset * (1 - self.details_reveal:get()))
end

---@param dt number
function SelectedSongPanel:update(dt)
	self.details_opacity:update(dt)
	local inputs = self.screen and self.screen.inputs
	local hovered = inputs and self:isMouseOver(inputs.mouse_x, inputs.mouse_y) or false
	self.details_reveal:set(hovered and 1 or 0):update(dt)
	self.details_container:setOffset(0, self.details_hidden_offset * (1 - self.details_reveal:get()))
end

---@param cvf ui.formatters.ChartviewFormatter
function SelectedSongPanel:bind(cvf)
	self.details_opacity:snap(0):set(1)
	self.title = cvf:getTitle()
	self.artist = cvf:getArtist()
	self.chart_preview:bind(cvf)
end

return SelectedSongPanel
