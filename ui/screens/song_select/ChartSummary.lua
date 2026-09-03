local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select.ChartSummary : gui.View
---@operator call: ui.screens.song_select.ChartSummary
local ChartSummary = View + {}

local PADDING = 6
local DIFFICULTY_WIDTH = 285
local DIFFICULTY_BAR_WIDTH = 3
local TEXT_OFFSET_Y = 3

---@param cvf ui.formatters.ChartviewFormatter
function ChartSummary:new(cvf)
	View.new(self)
	self.cvf = cvf
	self.background = NineSliceUsage(Resources.nine_slices.song_select_summary)
	self.rating_font = Resources.getFont("regular", 36)
	self.mode_font = Resources.getFont("medium", 18)
	self.metadata_font = Resources.getFont("medium", 15)
	self.rating = "0.0"
	self.mode = "NO CHART"
	self.duration = "0:00"
	self.note_count = "0"
	self.tempo = "0 BPM"
	self.ln_ratio = "0%"
	self.format = "-"
	self.difficulty_color = Colors.text
	cvf.settings:subscribeChoice(Settings.keys.select.diff_column, function()
		self:bind()
	end)
	self:bind()
end

function ChartSummary:bind()
	local cvf = self.cvf
	if not cvf.chartview.hash then
		self.rating = "0.0"
		self.difficulty_color = Colors.text
		self.mode = "NO CHART"
		self.duration = "0:00"
		self.note_count = "0"
		self.tempo = "0 BPM"
		self.ln_ratio = "0%"
		self.format = "-"
		return
	end
	local difficulty = cvf:getDifficulty()
	self.rating = difficulty.value
	self.difficulty_color = difficulty.color
	self.mode = cvf:getMode()
	self.duration = cvf:getDuration()
	self.note_count = cvf:getNoteCount()
	self.tempo = cvf:getTempo().avg .. " BPM"
	self.ln_ratio = cvf:getLongNoteRatio().value
	self.format = cvf:getFormat()
end

---@param sprite gui.AtlasImage
---@param value string
---@param x number
---@param y number
local function drawMetadata(sprite, value, x, y)
	Painter.setColorTable(Colors.muted)
	local width, height = sprite:getDimensions()
	local scale = math.min(18 / width, 18 / height)
	sprite:draw(x, y + (18 - height * scale) / 2 + TEXT_OFFSET_Y, 0, scale, scale)
	Painter.setColorTable(Colors.text)
	love.graphics.print(value, x + 25, y + TEXT_OFFSET_Y)
end

function ChartSummary:draw()
	Painter.snapToPixel()
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)

	local inner_height = self.height - PADDING * 2
	Painter.setColorTable(self.difficulty_color)
	Painter.setOpacity(0.08)
	Resources.sprites.chart_summary_difficulty_gradient:draw(PADDING, PADDING)
	Painter.setOpacity(1)
	Resources.sprites.pixel:draw(PADDING, PADDING, 0, DIFFICULTY_BAR_WIDTH, inner_height)

	local lg = love.graphics
	lg.setFont(self.rating_font)
	Painter.setColorTable(self.difficulty_color)
	lg.print(self.rating, PADDING + 14, PADDING + 8 + TEXT_OFFSET_Y)
	lg.setFont(self.mode_font)
	Painter.setColorTable(Colors.text)
	lg.print(self.mode, PADDING + 125, PADDING + 18 + TEXT_OFFSET_Y)

	local metadata_x = PADDING + DIFFICULTY_WIDTH
	Painter.setColorTable(Colors.divider)
	Resources.sprites.pixel:draw(metadata_x, PADDING, 0, 1, inner_height)
	metadata_x = metadata_x + 13
	local available_width = self.width - metadata_x - PADDING
	local column_width = available_width / 3
	lg.setFont(self.metadata_font)
	drawMetadata(Resources.sprites.icon_clock, self.duration, metadata_x, PADDING + 5)
	drawMetadata(Resources.sprites.icon_music, self.note_count, metadata_x, PADDING + 32)
	drawMetadata(Resources.sprites.icon_metronome, self.tempo, metadata_x + column_width, PADDING + 5)
	Painter.setColorTable(Colors.muted)
	lg.print("LN", metadata_x + column_width, PADDING + 32 + TEXT_OFFSET_Y)
	Painter.setColorTable(Colors.accent)
	lg.print(self.ln_ratio, metadata_x + column_width + 25, PADDING + 32 + TEXT_OFFSET_Y)
	drawMetadata(Resources.sprites.icon_file, self.format, metadata_x + column_width * 2, PADDING + 5)
end

return ChartSummary
