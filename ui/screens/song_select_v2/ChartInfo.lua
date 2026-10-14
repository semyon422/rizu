local utf8 = require("utf8")
local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")

local lg = love.graphics

-- Layout follows .chart in result_design/select.css.
local HEIGHT = 112
local PADDING_X = 6
local TOP_PADDING = 6
local CELL_GAP = 44
local CELLS_BOTTOM = 6
local LABEL_SPACING = 0.3
local CELL_LABEL_SPACING = 0.18
local PATTERN_SEPARATOR = "  ·  "

---Draws text with extra space after every character, like CSS letter-spacing.
---@param font love.Font
---@param text string
---@param x number
---@param y number
---@param spacing number In em.
---@return number end_x
local function printSpaced(font, text, x, y, spacing)
	local extra = spacing * font:getHeight() / 1.2
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		lg.print(char, x, y)
		x = x + font:getWidth(char) + extra
	end
	return x
end

---@param font love.Font
---@param text string
---@param spacing number
---@return number
local function spacedWidth(font, text, spacing)
	return font:getWidth(text) + utf8.len(text) * spacing * font:getHeight() / 1.2
end

---The difficulty, its patterns and the chart facts above the difficulty tabs.
---@class ui.screens.song_select_v2.ChartInfo : gui.View
---@operator call: ui.screens.song_select_v2.ChartInfo
---@field cvf ui.formatters.ChartviewFormatter?
---@field difficulty {value: string, postfix: string, color: gui.Color}
---@field patterns string
---@field cells {value: string, label: string}[]
local ChartInfo = View + {}

ChartInfo.HEIGHT = HEIGHT

function ChartInfo:new()
	View.new(self)
	self.label_font = Resources.getFont("bold", 20)
	self.postfix_font = Resources.getFont("medium", 24)
	self.patterns_font = Resources.getFont("medium", 24)
	self.big_font = Resources.getFont("bold", 76)
	self.value_font = Resources.getFont("medium", 34)
	self.cell_label_font = Resources.getFont("medium", 13)
	self.difficulty = {value = "", postfix = "", color = Colors.text}
	self.patterns = ""
	self.cells = {}
end

---@param cvf ui.formatters.ChartviewFormatter
function ChartInfo:bind(cvf)
	if not self.cvf then
		-- The difficulty column decides the number, its name and its colour.
		cvf.settings:subscribeChoice(Settings.keys.select.diff_column, function()
			self:bind(cvf)
		end)
	end
	self.cvf = cvf
	self.difficulty = cvf:getDifficulty()

	local patterns = cvf:getPatterns()
	local names = {}
	for _, name in ipairs({patterns.top_full, patterns.second_full}) do
		names[#names + 1] = name:sub(1, 1):upper() .. name:sub(2)
	end
	self.patterns = table.concat(names, PATTERN_SEPARATOR)

	self.cells = {
		{value = (cvf:getMode():gsub(" %(EXPERIMENTAL%)$", "")), label = "KEYS"},
		{value = cvf:getDuration(), label = "LENGTH"},
		{value = cvf:getNoteCount(), label = "NOTES"},
		{value = cvf:getTempo().avg, label = "BPM"},
		{value = cvf:getLongNoteRatio().value, label = "LN"},
	}
end

function ChartInfo:draw()
	if not self.cvf then
		return
	end
	Painter.snapToPixel()

	-- DIFFICULTY <postfix>
	lg.setFont(self.label_font)
	Painter.setColorTable(Colors.muted)
	local x = printSpaced(self.label_font, "DIFFICULTY", PADDING_X, TOP_PADDING, LABEL_SPACING)
	lg.setFont(self.postfix_font)
	Painter.setColorTable(Colors.accent)
	local label_baseline = TOP_PADDING + self.label_font:getBaseline()
	lg.print(self.difficulty.postfix, x + 16 - LABEL_SPACING * self.label_font:getHeight() / 1.2,
		label_baseline - self.postfix_font:getBaseline())

	-- Patterns, right aligned on the same row.
	lg.setFont(self.patterns_font)
	Painter.setColorTable(Colors.muted)
	lg.print(self.patterns, self.width - PADDING_X - self.patterns_font:getWidth(self.patterns),
		label_baseline - self.patterns_font:getBaseline())

	-- Big difficulty number.
	local big_y = self.height - self.big_font:getHeight()
	Painter.setColorTable(self.difficulty.color)
	lg.setFont(self.big_font)
	lg.print(self.difficulty.value, PADDING_X - 3, big_y)

	-- Facts, right aligned: value over caption.
	local cells_right = self.width - PADDING_X
	local label_height = self.cell_label_font:getHeight()
	local label_y = self.height - CELLS_BOTTOM - label_height
	local value_y = label_y - 2 - self.value_font:getHeight() * 1.0
	for i = #self.cells, 1, -1 do
		local cell = self.cells[i]
		local label_width = spacedWidth(self.cell_label_font, cell.label, CELL_LABEL_SPACING)
		local width = math.max(self.value_font:getWidth(cell.value), label_width)
		local left = cells_right - width
		lg.setFont(self.value_font)
		Painter.setColorTable(Colors.text)
		lg.print(cell.value, left, value_y)
		lg.setFont(self.cell_label_font)
		Painter.setColorTable(Colors.muted)
		printSpaced(self.cell_label_font, cell.label, left, label_y, CELL_LABEL_SPACING)
		cells_right = left - CELL_GAP
	end
	Painter.setColorRgb(1, 1, 1)
end

return ChartInfo
