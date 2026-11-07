local View = require("gui.View")
local Resources = require("ui.Resources")
local InputMode = require("chart.core.InputMode")
local NotesPreview = require("rizu.preview.NotesPreview")
local pattern_classifier = require("chart.scoring.pattern_classifier")

local lg = love.graphics

-- shortcut: a testing strip that decodes the notes preview and runs chart.scoring.pattern_classifier on the UI thread,
-- spread over frames; move it into the library worker and rizu.api when the pattern view gets a real design

local BUDGET = 0.002 -- seconds of work per frame; the decode (about 10 ms for 5k notes) runs in one piece

---The share of the selected chart's sections each label fits (0.5+, a section can fit several, e.g. handstream and
---jacks) and their median BPM: the skillsets always, in a fixed order, then the patterns found.
---@class ui.screens.song_select_v2.PatternStrip : gui.View
---@operator call: ui.screens.song_select_v2.PatternStrip
---@field sections chart.scoring.pattern_classifier.Section[]?
---@field summary string
---@field parts {label: string, share: number, bpm: number?, text: string, skillset: boolean}[] each label with the share of sections it fits and their median BPM, skillsets first
---@field key string? which chart the sections are of
---@field job thread? the running analysis, returns the sections
---@field chartview ui.screens.song_select_v2.PatternStrip.Chart?
local PatternStrip = View + {}

local MAX_PATTERNS = 6
PatternStrip.HEIGHT = 290

local SKILLSETS = {"speed", "stamina", "jacks", "technical"}
local IS_SKILLSET = {} ---@type {[string]: true}
for _, l in ipairs(SKILLSETS) do IS_SKILLSET[l] = true end

local COLORS = {
	speed = {0.38, 0.76, 1},
	stamina = {0.42, 0.9, 0.62},
	jacks = {1, 0.52, 0.45},
	technical = {0.76, 0.58, 1},
}
local PATTERN_COLOR = {0.8, 0.82, 0.88}
local PANEL_COLOR = {0.05, 0.06, 0.09, 0.78}
local PAD, GAP, ROW_PAD = 12, 16, 10

function PatternStrip:new()
	View.new(self)
	self.font = Resources.getFont("medium", 20)
	self.small_font = Resources.getFont("medium", 14)
	self.bold_font = Resources.getFont("bold", 20)
	self.summary = ""
	self.parts = {}
end

---@alias ui.screens.song_select_v2.PatternStrip.Chart {hash: string?, index: integer?, chartdiff_inputmode: string?, notes_preview: string?, chartmeta_mode: string?, artist: string?, title: string?, name: string?}

---A mania chart's notes from its notes preview, sorted by time then column; nil for other gamemodes or no preview.
---Errors on a broken preview.
---@param chartview ui.screens.song_select_v2.PatternStrip.Chart
---@return {time: number, column: integer, end_time: number?}[]?
function PatternStrip.notes(chartview)
	local inputmode = chartview.chartdiff_inputmode
	if not inputmode or not chartview.notes_preview or (chartview.chartmeta_mode and chartview.chartmeta_mode ~= "mania") then
		return
	end
	-- the notes preview's decoder, ~6x faster than chart.format.sph.ChartDecoder and the same notes
	local preview = NotesPreview(chartview.notes_preview, InputMode(inputmode):getColumns())
	local notes = {} ---@type {time: number, column: integer, end_time: number?}[]
	for column, list in ipairs(preview.columns) do
		for _, note in ipairs(list) do
			table.insert(notes, {time = note.time, column = column, end_time = note.end_time > note.time and note.end_time or nil})
		end
	end
	table.sort(notes, function(a, b)
		if a.time == b.time then
			return a.column < b.column
		end
		return a.time < b.time
	end)
	return notes
end

---Runs in a coroutine, yields after the decode and each section.
---@param chartview ui.screens.song_select_v2.PatternStrip.Chart
---@return chart.scoring.pattern_classifier.Section[]?
local function analyze(chartview)
	local notes = PatternStrip.notes(chartview)
	if not notes then
		return
	end
	coroutine.yield()
	return pattern_classifier.analyze(notes, chartview.chartdiff_inputmode, coroutine.yield)
end

---@param cvf ui.formatters.ChartviewFormatter
function PatternStrip:bind(cvf)
	local chartview = cvf.chartview --[[@as ui.screens.song_select_v2.PatternStrip.Chart]]
	local key = tostring(chartview.hash) .. ":" .. tostring(chartview.index) .. ":" .. tostring(chartview.notes_preview and #chartview.notes_preview)
	if key == self.key then
		return
	end
	self.key = key
	self.sections = nil
	self.summary = "patterns: analyzing..."
	self.job = coroutine.create(analyze)
	self.chartview = chartview
end

---@param dt number
function PatternStrip:update(dt)
	local job = self.job
	if not job then
		return
	end
	local stop = love.timer.getTime() + BUDGET
	local ok, sections = true, nil ---@type boolean, any
	repeat
		ok, sections = coroutine.resume(job, self.chartview)
	until coroutine.status(job) == "dead" or love.timer.getTime() > stop
	if coroutine.status(job) ~= "dead" then
		return
	end
	self.job = nil
	if not ok then
		self.summary = "patterns: " .. tostring(sections)
		return
	end
	self:setSections(sections)
end

---@param sections chart.scoring.pattern_classifier.Section[]?
function PatternStrip:setSections(sections)
	self.sections = sections and #sections > 0 and sections or nil
	self.summary = ""
	self.parts = {}
	if not self.sections then
		return
	end
	local count = {} ---@type {[string]: integer}
	local bpms = {} ---@type {[string]: number[]}
	for _, sec in ipairs(self.sections) do
		for l, v in pairs(sec.labels) do
			if v >= 0.5 then
				count[l] = (count[l] or 0) + 1
				bpms[l] = bpms[l] or {}
				table.insert(bpms[l], sec.bpm)
			end
		end
	end
	local patterns = {} ---@type string[]
	for l in pairs(count) do
		if not IS_SKILLSET[l] then table.insert(patterns, l) end
	end
	table.sort(patterns, function(a, b) return count[a] > count[b] or count[a] == count[b] and a < b end)
	for i = #patterns, MAX_PATTERNS + 1, -1 do patterns[i] = nil end
	local labels = {unpack(SKILLSETS)}
	table.move(patterns, 1, #patterns, #labels + 1, labels)
	local texts = {}
	for _, l in ipairs(labels) do
		local share = (count[l] or 0) / #self.sections
		local text = ("%s %d%%"):format(l, share * 100 + 0.5)
		local b = bpms[l]
		local bpm ---@type number?
		if b and #b > 0 then
			table.sort(b)
			bpm = b[math.ceil(#b / 2)]
			text = text .. (" %d BPM"):format(bpm + 0.5)
		end
		table.insert(self.parts, {label = l, share = share, bpm = bpm, text = text, skillset = IS_SKILLSET[l] or false})
		table.insert(texts, text)
	end
	self.summary = table.concat(texts, "  ")
end

---@param text string
---@param x number right edge
---@param y number
local function print_right(text, x, y)
	lg.print(text, x - lg.getFont():getWidth(text), y)
end

function PatternStrip:draw()
	if #self.parts == 0 then
		lg.setFont(self.font)
		lg.setColor(1, 1, 1, 0.9)
		lg.print(self.summary, PAD, PAD)
		return
	end
	-- skillset rows filled up to their share, then the smaller patterns as a table
	local big, small = self.font, self.small_font
	local name_w = 0
	for _, part in ipairs(self.parts) do
		name_w = math.max(name_w, (part.skillset and self.bold_font or small):getWidth((part.label:gsub("_", " "))))
	end
	local share_w, bpm_w = big:getWidth("100%"), big:getWidth("000 BPM")
	local width = PAD * 2 + ROW_PAD * 2 + name_w + GAP + share_w + GAP + bpm_w
	local row_h = big:getHeight() + 8
	local small_row = small:getHeight() + 2
	local n_patterns = #self.parts - #SKILLSETS
	local height = PAD * 2 + #SKILLSETS * (row_h + 4) - 4 + (n_patterns > 0 and 13 + n_patterns * small_row or 0)

	lg.setColor(PANEL_COLOR)
	lg.rectangle("fill", 0, 0, width, height)
	local inner = width - PAD * 2
	local left, right = PAD + ROW_PAD, width - PAD - ROW_PAD
	local share_x = right - bpm_w - GAP
	local y = PAD
	for i, part in ipairs(self.parts) do
		local bpm = part.bpm and ("%d BPM"):format(part.bpm + 0.5) or "-"
		local share = ("%d%%"):format(part.share * 100 + 0.5)
		if part.skillset then
			local color = COLORS[part.label]
			local alpha = part.share > 0 and 1 or 0.45
			lg.setColor(1, 1, 1, 0.05)
			lg.rectangle("fill", PAD, y, inner, row_h)
			lg.setColor(color[1], color[2], color[3], 0.45)
			lg.rectangle("fill", PAD, y, inner * part.share, row_h)
			local ty = y + 4
			lg.setFont(self.bold_font)
			lg.setColor(color[1], color[2], color[3], alpha)
			lg.print(part.label, left, ty)
			lg.setFont(big)
			lg.setColor(1, 1, 1, 0.95 * alpha)
			print_right(share, share_x, ty)
			lg.setColor(1, 1, 1, 0.55 * alpha)
			print_right(bpm, right, ty)
			y = y + row_h + 4
		else
			if i == #SKILLSETS + 1 then
				lg.setColor(1, 1, 1, 0.12)
				lg.rectangle("fill", PAD, y + 2, inner, 1)
				y = y + 13
			end
			lg.setFont(small)
			lg.setColor(PATTERN_COLOR[1], PATTERN_COLOR[2], PATTERN_COLOR[3], 0.85)
			lg.print((part.label:gsub("_", " ")), left, y)
			print_right(share, share_x, y)
			lg.setColor(1, 1, 1, 0.45)
			print_right(bpm, right, y)
			y = y + small_row
		end
	end
end

return PatternStrip
