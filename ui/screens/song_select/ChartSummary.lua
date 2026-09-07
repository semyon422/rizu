local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local SpriteBatch = require("gui.SpriteBatch")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local Painter = require("gui.Painter")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select.ChartSummary : gui.View
---@operator call: ui.screens.song_select.ChartSummary
local ChartSummary = View + {}

local OUTER_PADDING = 10
local CHALLENGE_GAP = 8
local CHIP_HEIGHT = 34
local METADATA_MIN_WIDTH = 300
local METADATA_MAX_WIDTH = 520
local METADATA_GAP = 24

---@param cvf ui.formatters.ChartviewFormatter
function ChartSummary:new(cvf)
	View.new(self)
	self.cvf = cvf
	self:setClip(true)
	self.background = NineSliceUsage(Resources.nine_slices.song_select_summary)
	self.chip = NineSliceUsage(Resources.nine_slices.chart_summary_chip)
	self.rating_font = Resources.getFont("medium", 22)
	self.value_font = Resources.getFont("medium", 18)
	self.challenge_font = Resources.getFont("medium", 16)
	self.label_font = Resources.getFont("bold", 9)
	self.rating_text = love.graphics.newTextBatch(self.rating_font)
	self.challenge_text = love.graphics.newTextBatch(self.challenge_font)
	self.label_text = love.graphics.newTextBatch(self.label_font)
	self.value_text = love.graphics.newTextBatch(self.value_font)
	self.icons = SpriteBatch(Resources.sprites.pixel, 5, "dynamic")
	self.rendered_width = -1
	self.has_chart = false
	self.rating = "0.0"
	self.difficulty_postfix = "USER"
	self.level = nil
	self.mode = "NO CHART"
	self.duration = "0:00"
	self.note_count = "0"
	self.tempo = "0"
	self.ln_ratio = "0%"
	self.difficulty_color = Colors.text
	self.rating_background_color = {}
	cvf.settings:subscribeChoice(Settings.keys.select.diff_column, function()
		self:bind()
	end)
	self:bind()
end

function ChartSummary:bind()
	local cvf = self.cvf
	self.has_chart = cvf.chartview.hash ~= nil
	if not self.has_chart then
		self.rating = "0.0"
		self.difficulty_postfix = "USER"
		self.level = nil
		self.difficulty_color = Colors.text
		self.mode = "NO CHART"
		self.duration = "0:00"
		self.note_count = "0"
		self.tempo = "0"
		self.ln_ratio = "0%"
		self:rebuild()
		return
	end
	local difficulty = cvf:getDifficulty()
	self.rating = difficulty.value
	self.difficulty_postfix = difficulty.postfix
	local level = cvf:getLevel()
	self.level = tonumber(level) ~= 0 and level or nil
	self.difficulty_color = difficulty.color
	self.mode = cvf:getMode()
	self.duration = cvf:getDuration()
	self.note_count = cvf:getNoteCount()
	self.tempo = cvf:getTempo().avg
	self.ln_ratio = cvf:getLongNoteRatio().value
	self:rebuild()
end

---@param batch gui.SpriteBatch
---@param sprite gui.AtlasImage
---@param x number
---@param y number
local function addIcon(batch, sprite, x, y)
	local width, height = sprite:getDimensions()
	local scale = math.min(18 / width, 18 / height)
	batch:add(sprite, x, y + (18 - height * scale) / 2, 0, scale, scale)
end

function ChartSummary:rebuild()
	Color.mix_to(self.rating_background_color, Colors.surface, self.difficulty_color, 0.1)

	local center_y = self.height / 2
	local chip_y = center_y - CHIP_HEIGHT / 2
	local chip_padding = 12
	local inline_gap = 7
	local difficulty_postfix = self.difficulty_postfix
	local level_label = "LV"
	local ln_label = "LN"
	local rating_width = chip_padding * 2
		+ self.rating_font:getWidth(self.rating)
		+ inline_gap
		+ self.challenge_font:getWidth(difficulty_postfix)
	local level_width = self.level and chip_padding * 2
		+ self.label_font:getWidth(level_label)
		+ inline_gap
		+ self.challenge_font:getWidth(self.level) or 0
	local mode_width = chip_padding * 2 + self.challenge_font:getWidth(self.mode)
	local ln_width = chip_padding * 2
		+ self.label_font:getWidth(ln_label)
		+ inline_gap
		+ self.challenge_font:getWidth(self.ln_ratio)
	local rating_x = OUTER_PADDING + 6
	local level_x = rating_x + rating_width + CHALLENGE_GAP
	local mode_x = level_x + (self.level and level_width + CHALLENGE_GAP or 0)
	local ln_x = mode_x + mode_width + CHALLENGE_GAP
	self.chips = {
		{rating_x, chip_y, rating_width, self.rating_background_color},
	}
	if self.has_chart then
		if self.level then
			self.chips[#self.chips + 1] = {level_x, chip_y, level_width, Colors.surface}
		end
		self.chips[#self.chips + 1] = {mode_x, chip_y, mode_width, Colors.surface}
		self.chips[#self.chips + 1] = {ln_x, chip_y, ln_width, Colors.surface}
	end

	self.rating_text:clear()
	self.rating_text:add({self.difficulty_color, self.rating}, rating_x + chip_padding, chip_y + 5)
	self.challenge_text:clear()
	self.challenge_text:add({self.difficulty_color, difficulty_postfix},
		rating_x + rating_width - chip_padding - self.challenge_font:getWidth(difficulty_postfix), chip_y + 8)
	self.label_text:clear()
	if self.has_chart then
		if self.level then
			self.label_text:add({Colors.muted, level_label}, level_x + chip_padding, chip_y + 12)
			self.challenge_text:add({Colors.text, self.level},
				level_x + chip_padding + self.label_font:getWidth(level_label) + inline_gap, chip_y + 7)
		end
		self.challenge_text:add({Colors.text, self.mode}, mode_x + chip_padding, chip_y + 7)
		self.label_text:add({Colors.muted, ln_label}, ln_x + chip_padding, chip_y + 12)
		self.challenge_text:add({Colors.text, self.ln_ratio},
			ln_x + chip_padding + self.label_font:getWidth(ln_label) + inline_gap, chip_y + 7)
	end

	local challenge_end = self.has_chart and ln_x + ln_width or rating_x + rating_width
	local available_metadata_width = self.width - challenge_end - METADATA_GAP - OUTER_PADDING
	local show_metadata = available_metadata_width >= METADATA_MIN_WIDTH
	local metadata_width = math.min(METADATA_MAX_WIDTH, math.max(0, available_metadata_width))
	local metadata_x = self.width - OUTER_PADDING - metadata_width
	local column_width = metadata_width / 3

	self.value_text:clear()
	self.icons:clear()
	if show_metadata then
		self.label_text:add({Colors.muted, "LENGTH"}, metadata_x + 39, center_y - 17)
		self.label_text:add({Colors.muted, "NOTES"}, metadata_x + column_width + 39, center_y - 17)
		self.label_text:add({Colors.muted, "TEMPO"}, metadata_x + column_width * 2 + 39, center_y - 17)
		local value_y = math.floor(center_y - 5 + 0.5)
		self.value_text:add({Colors.text, self.duration}, math.floor(metadata_x + 39 + 0.5), value_y)
		self.value_text:add({Colors.text, self.note_count}, math.floor(metadata_x + column_width + 39 + 0.5), value_y)
		self.value_text:add({Colors.text, self.tempo}, math.floor(metadata_x + column_width * 2 + 39 + 0.5), value_y)
		self.label_text:add({Colors.muted, "BPM"}, metadata_x + column_width * 2 + 39 + self.value_font:getWidth(self.tempo) + 6, center_y + 4)

		self.icons:setColor(Colors.muted)
		addIcon(self.icons, Resources.sprites.icon_clock, metadata_x + 13, center_y - 9)
		addIcon(self.icons, Resources.sprites.icon_music, metadata_x + column_width + 13, center_y - 9)
		addIcon(self.icons, Resources.sprites.icon_metronome, metadata_x + column_width * 2 + 13, center_y - 9)
		self.icons:setColor(Colors.divider)
		self.icons:add(Resources.sprites.pixel, metadata_x + column_width, OUTER_PADDING + 3, 0, 1, self.height - OUTER_PADDING * 2 - 6)
		self.icons:add(Resources.sprites.pixel, metadata_x + column_width * 2, OUTER_PADDING + 3, 0, 1, self.height - OUTER_PADDING * 2 - 6)
	end
	self.icons:flush()
	self.rendered_width = self.width
end

function ChartSummary:draw()
	if self.rendered_width ~= self.width then
		self:rebuild()
	end
	Painter.snapToPixel()
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)
	for _, chip in ipairs(self.chips) do
		Painter.setColorTable(chip[4])
		love.graphics.push("transform")
		love.graphics.translate(chip[1], chip[2])
		self.chip:drawFixedScale(chip[3], CHIP_HEIGHT, assert(self.screen).ui_scale)
		love.graphics.pop()
	end
	Painter.setColorRgb(1, 1, 1)
	self.icons:draw()
	love.graphics.draw(self.rating_text)
	love.graphics.draw(self.challenge_text)
	love.graphics.draw(self.label_text)
	Painter.snapToPixel()
	love.graphics.draw(self.value_text)
end

return ChartSummary
