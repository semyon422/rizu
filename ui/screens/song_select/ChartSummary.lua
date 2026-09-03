local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local SpriteBatch = require("gui.SpriteBatch")
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
	self.rating_text = love.graphics.newTextBatch(self.rating_font)
	self.mode_text = love.graphics.newTextBatch(self.mode_font)
	self.metadata_text = love.graphics.newTextBatch(self.metadata_font)
	self.icons = SpriteBatch(Resources.sprites.pixel, 6, "dynamic")
	self.rendered_width = -1
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
		self:rebuild()
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
	self:rebuild()
end

---@param batch gui.SpriteBatch
---@param sprite gui.AtlasImage
---@param x number
---@param y number
local function addIcon(batch, sprite, x, y)
	local width, height = sprite:getDimensions()
	local scale = math.min(18 / width, 18 / height)
	batch:add(sprite, x, y + (18 - height * scale) / 2 + TEXT_OFFSET_Y, 0, scale, scale)
end

function ChartSummary:rebuild()
	local metadata_x = PADDING + DIFFICULTY_WIDTH
	local available_width = self.width - metadata_x - 13 - PADDING
	local column_width = available_width / 3
	metadata_x = metadata_x + 13

	self.rating_text:clear()
	self.rating_text:add({self.difficulty_color, self.rating}, PADDING + 14, PADDING + 8 + TEXT_OFFSET_Y)
	self.mode_text:clear()
	self.mode_text:add({Colors.text, self.mode}, PADDING + 125, PADDING + 18 + TEXT_OFFSET_Y)
	self.metadata_text:clear()
	self.metadata_text:add({Colors.text, self.duration}, metadata_x + 25, PADDING + 5 + TEXT_OFFSET_Y)
	self.metadata_text:add({Colors.text, self.note_count}, metadata_x + 25, PADDING + 32 + TEXT_OFFSET_Y)
	self.metadata_text:add({Colors.text, self.tempo}, metadata_x + column_width + 25, PADDING + 5 + TEXT_OFFSET_Y)
	self.metadata_text:add({Colors.muted, "LN"}, metadata_x + column_width, PADDING + 32 + TEXT_OFFSET_Y)
	self.metadata_text:add({Colors.accent, self.ln_ratio}, metadata_x + column_width + 25, PADDING + 32 + TEXT_OFFSET_Y)
	self.metadata_text:add({Colors.text, self.format}, metadata_x + column_width * 2 + 25, PADDING + 5 + TEXT_OFFSET_Y)

	local inner_height = self.height - PADDING * 2
	self.icons:clear()
	self.icons:setColor(self.difficulty_color)
	self.icons:add(Resources.sprites.pixel, PADDING, PADDING, 0, DIFFICULTY_BAR_WIDTH, inner_height)
	self.icons:setColor(Colors.divider)
	self.icons:add(Resources.sprites.pixel, PADDING + DIFFICULTY_WIDTH, PADDING, 0, 1, inner_height)
	self.icons:setColor(Colors.muted)
	addIcon(self.icons, Resources.sprites.icon_clock, metadata_x, PADDING + 5)
	addIcon(self.icons, Resources.sprites.icon_music, metadata_x, PADDING + 32)
	addIcon(self.icons, Resources.sprites.icon_metronome, metadata_x + column_width, PADDING + 5)
	addIcon(self.icons, Resources.sprites.icon_file, metadata_x + column_width * 2, PADDING + 5)
	self.icons:flush()
	self.rendered_width = self.width
end

function ChartSummary:draw()
	if self.rendered_width ~= self.width then
		self:rebuild()
	end
	Painter.snapToPixel()
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)

	Painter.setColorTable(self.difficulty_color)
	Painter.setOpacity(0.08)
	Resources.sprites.chart_summary_difficulty_gradient:draw(PADDING, PADDING)
	Painter.setOpacity(1)
	Painter.setColorRgb(1, 1, 1)
	self.icons:draw()
	love.graphics.draw(self.rating_text)
	love.graphics.draw(self.mode_text)
	love.graphics.draw(self.metadata_text)
end

return ChartSummary
