local utf8 = require("utf8")
local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local DanBadge = require("ui.screens.song_select_v2.DanBadge")

local lg = love.graphics

-- Layout follows .chart in result_design/select.css.
local HEIGHT = 112
local PADDING_X = 6
local TOP_PADDING = 6
local CELL_GAP = 44
local LEADING_ZERO = {Colors.muted[1], Colors.muted[2], Colors.muted[3], (Colors.muted[4] or 1) * 0.3}
-- Counts are written with this many digits, the leading zeros grayed: the fact keeps its width.
local CELL_DIGITS = {NOTES = 5, BPM = 3, LN = 3}
local CELLS_BOTTOM = 6
local LABEL_SPACING = 0.3
local CELL_LABEL_SPACING = 0.18
-- The big number is not monospaced: a fixed box keeps the dan badge from shifting with its digits.
local NUMBER_WIDTH = 200
local NUMBER_FLOW_SPEED = 12

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

---The difficulty and the chart facts above the difficulty tabs.
---@class ui.screens.song_select_v2.ChartInfo : gui.View
---@operator call: ui.screens.song_select_v2.ChartInfo
---@field cvf ui.formatters.ChartviewFormatter?
---@field difficulty {value: string, postfix: string, color: gui.Color, dan: string?}
---@field dan_badge ui.screens.song_select_v2.DanBadge
---@field shown_value number? The number drawn, on its way to the difficulty's. Nil for a value that is not a number.
---@field shown_color gui.Color
---@field cells {value: string, label: string}[]
---@field shown_cells {[string]: number} By label: the number drawn for a fact that is one, on its way to its value
local ChartInfo = View + {}

ChartInfo.HEIGHT = HEIGHT

function ChartInfo:new()
	View.new(self)
	self.label_font = Resources.getFont("bold", 20)
	self.postfix_font = Resources.getFont("medium", 24)
	self.big_font = Resources.getFont("bold", 76)
	self.value_font = Resources.getFont("medium", 34)
	self.digit_width = 0
	for digit = 0, 9 do
		self.digit_width = math.max(self.digit_width, self.value_font:getWidth(tostring(digit)))
	end
	self.cell_label_font = Resources.getFont("medium", 13)
	self.difficulty = {value = "", postfix = "", color = Colors.text}
	self.shown_color = {Colors.text[1], Colors.text[2], Colors.text[3], Colors.text[4] or 1}
	self.cells = {}
	self.shown_cells = {}
	self.dan_badge = self:add(DanBadge())
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
	self.difficulty, self.cells = ChartInfo.collect(cvf)

	-- A number flows to the new one; anything else, like "—", is shown at once.
	if not (tonumber(self.difficulty.value) and self.shown_value) then
		self.shown_value = tonumber(self.difficulty.value)
		for i = 1, 4 do self.shown_color[i] = self.difficulty.color[i] or 1 end
	end

	local shown = {} ---@type {[string]: number}
	for _, cell in ipairs(self.cells) do
		local number = ChartInfo.parseCell(cell.value)
		shown[cell.label] = number and (self.shown_cells[cell.label] or number)
	end
	self.shown_cells = shown

	-- After the big number's box, centered on it.
	local number_height = self.big_font:getHeight()
	self.dan_badge:setDan(self.difficulty.dan)
	self.dan_badge:setPosition(PADDING_X - 3 + NUMBER_WIDTH + 18,
		HEIGHT - number_height + (number_height - DanBadge.HEIGHT) / 2)
end

---Facts that are a count, a percentage or a duration flow like the difficulty does.
---@param value string
---@return number? number
---@return string? format For string.format, the number rounded
function ChartInfo.parseCell(value)
	local minutes, seconds = value:match("^(%d+):(%d%d)$")
	if minutes then
		return minutes * 60 + seconds, "%d:%02d"
	end
	local count, percent = value:match("^(%d+)(%%?)$")
	if count then
		return tonumber(count), percent == "" and "%d" or "%d%%"
	end
end

---A fact's number as text, padded with zeros to a fixed width.
---@param label string
---@param number number
---@param format string From parseCell
---@return string text
---@return integer gray How many characters at the start are leading zeros
function ChartInfo.padCell(label, number, format)
	number = math.floor(number + 0.5)
	local text
	if format == "%d:%02d" then
		text = ("%02d:%02d"):format(math.floor(number / 60), number % 60)
	else
		text = format:gsub("%%d", "%%0" .. (CELL_DIGITS[label] or 1) .. "d"):format(number)
	end
	-- The last character always stays, so zero reads "0" and not nothing.
	local gray = #text:sub(1, -2):match("^[0:]*")
	return text, gray
end

---Moves a value toward its target, a fraction of the way each second, and lands on it when close.
---@param value number
---@param target number
---@param dt number
---@param epsilon number
---@return number
function ChartInfo.approach(value, target, dt, epsilon)
	local diff = target - value
	if math.abs(diff) <= epsilon then
		return target
	end
	return value + diff * math.min(1, dt * NUMBER_FLOW_SPEED)
end

---@param dt number
function ChartInfo:update(dt)
	local target = tonumber(self.difficulty.value)
	if target and self.shown_value then
		self.shown_value = ChartInfo.approach(self.shown_value, target, dt, 0.02)
	end
	for i = 1, 4 do
		self.shown_color[i] = ChartInfo.approach(self.shown_color[i], self.difficulty.color[i] or 1, dt, 0.005)
	end
	for _, cell in ipairs(self.cells) do
		local shown = self.shown_cells[cell.label]
		if shown then
			self.shown_cells[cell.label] = ChartInfo.approach(shown, (ChartInfo.parseCell(cell.value)), dt, 0.05)
		end
	end
end

---The text of a fact: the number on its way, or the value as it is.
---@param cell {value: string, label: string}
---@param final boolean? The value the fact is going to, not the number now drawn
---@return string
---@return integer gray
function ChartInfo:getCellText(cell, final)
	local number, format = ChartInfo.parseCell(cell.value)
	if not number then
		return cell.value, 0
	end
	return ChartInfo.padCell(cell.label, final and number or self.shown_cells[cell.label] or number, format)
end

---Digits all take the width of the widest, so the text does not change its width with the digits.
---@param text string
---@param x number?
---@param y number?
---@param gray integer? Characters at the start drawn in the muted color
---@return number width
function ChartInfo:printTabular(text, x, y, gray)
	local font = self.value_font
	local digit = self.digit_width
	local start = x
	for i = 1, #text do
		local char = text:sub(i, i)
		local width = char:match("%d") and digit or font:getWidth(char)
		if x then
			Painter.setColorTable(i <= (gray or 0) and LEADING_ZERO or Colors.text)
			lg.print(char, x + (width - font:getWidth(char)) / 2, y)
			x = x + width
		else
			start = (start or 0) + width
		end
	end
	return x and x - start or start
end

---The texts the panel shows, so other screens (the video export) can draw the same facts.
---@param cvf ui.formatters.ChartviewFormatter
---@return {value: string, postfix: string, color: gui.Color, dan: string?} difficulty
---@return {value: string, label: string}[] cells
function ChartInfo.collect(cvf)
	return cvf:getDifficulty(), {
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

	-- Big difficulty number.
	local big_y = self.height - self.big_font:getHeight()
	Painter.setColorTable(self.shown_color)
	lg.setFont(self.big_font)
	lg.print(self.shown_value and ("%0.01f"):format(self.shown_value) or self.difficulty.value, PADDING_X - 3, big_y)

	-- Facts, right aligned: value over caption.
	local cells_right = self.width - PADDING_X
	local label_height = self.cell_label_font:getHeight()
	local label_y = self.height - CELLS_BOTTOM - label_height
	local value_y = label_y - 2 - self.value_font:getHeight() * 1.0
	for i = #self.cells, 1, -1 do
		local cell = self.cells[i]
		local label_width = spacedWidth(self.cell_label_font, cell.label, CELL_LABEL_SPACING)
		local value_width = self:printTabular((self:getCellText(cell, true)))
		local width = math.max(value_width, label_width)
		local left = cells_right - width
		lg.setFont(self.value_font)
		local text, gray = self:getCellText(cell)
		self:printTabular(text, cells_right - value_width, value_y, gray)
		lg.setFont(self.cell_label_font)
		Painter.setColorTable(Colors.muted)
		printSpaced(self.cell_label_font, cell.label, cells_right - label_width, label_y, CELL_LABEL_SPACING)
		cells_right = left - CELL_GAP
	end
	Painter.setColorRgb(1, 1, 1)
end

return ChartInfo
