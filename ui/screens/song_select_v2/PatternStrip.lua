local View = require("gui.View")
local Resources = require("ui.Resources")
local InputMode = require("chart.core.InputMode")
local NotesPreview = require("rizu.preview.NotesPreview")
local pattern_classifier = require("chart.scoring.pattern_classifier")
local RizuDifficulty = require("rizu.library.RizuDifficulty")

local lg = love.graphics

-- shortcut: a testing strip that decodes the notes preview and runs chart.scoring.pattern_classifier on the UI thread,
-- spread over frames; move it into the library worker and rizu.api when the pattern view gets a real design

local BUDGET = 0.002 -- seconds of work per frame; the decode (about 10 ms for 5k notes) runs in one piece

---The share of the selected chart's sections each label fits (0.5+, a section can fit several, e.g. handstream and
---jacks), their median BPM and their mean section difficulty: the skillsets always, in a fixed order, then the patterns
---found, ordered by difficulty-weighted share.
---@class ui.screens.song_select_v2.PatternStrip : gui.View
---@operator call: ui.screens.song_select_v2.PatternStrip
---@field sections chart.scoring.pattern_classifier.Section[]?
---@field summary string
---@field parts {label: string, share: number, bpm: number?, difficulty: number?, text: string, skillset: boolean}[] each label with the share of sections it fits, their median BPM and their mean section difficulty, skillsets first
---@field key string? which chart the sections are of
---@field job thread? the running analysis, returns the sections and the Rizu difficulty curve
---@field chartview ui.screens.song_select_v2.PatternStrip.Chart?
---@field debug_label string? the row clicked to show where it occurs in the chart
---@field row_bounds {label: string, y: number, h: number}[] rows of the last draw, for click hit-testing
local PatternStrip = View + {}

local MAX_PATTERNS = 6
PatternStrip.HEIGHT = 290
-- a section's difficulty is the 90th percentile of the Rizu curve inside it, to keep spikes
local SECTION_QUANTILE = 0.9

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

---The 90th percentile of the Rizu curve inside a section, or 1 without a curve so patterns count equally.
---@param curve {time: number, end_time: number, difficulty: number}[]?
---@param start number
---@param stop number
---@return number
function PatternStrip.sectionDifficulty(curve, start, stop)
	if not curve then
		return 1
	end
	local values = {} ---@type number[]
	for _, point in ipairs(curve) do
		if point.time < stop and point.end_time > start then
			table.insert(values, point.difficulty)
		end
	end
	if #values == 0 then
		return 0
	end
	table.sort(values)
	local pos = 1 + (#values - 1) * SECTION_QUANTILE
	local lo = math.floor(pos)
	local hi = math.min(#values, lo + 1)
	return values[lo] + (values[hi] - values[lo]) * (pos - lo)
end

---Runs in a coroutine, yields after the decode, each section and before the Rizu curve.
---@param chartview ui.screens.song_select_v2.PatternStrip.Chart
---@return chart.scoring.pattern_classifier.Section[]?, {time: number, end_time: number, difficulty: number}[]?
local function analyze(chartview)
	local notes = PatternStrip.notes(chartview)
	if not notes then
		return
	end
	coroutine.yield()
	local sections = pattern_classifier.analyze(notes, chartview.chartdiff_inputmode, coroutine.yield)
	if not sections then
		return
	end
	coroutine.yield()
	return sections, RizuDifficulty.rateCurve(notes, chartview.chartdiff_inputmode)
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
	self.debug_label = nil
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
	local ok, sections, curve = true, nil, nil ---@type boolean, any, any
	repeat
		ok, sections, curve = coroutine.resume(job, self.chartview)
	until coroutine.status(job) == "dead" or love.timer.getTime() > stop
	if coroutine.status(job) ~= "dead" then
		return
	end
	self.job = nil
	if not ok then
		self.summary = "patterns: " .. tostring(sections)
		return
	end
	self:setSections(sections, curve)
end

---@param sections chart.scoring.pattern_classifier.Section[]?
---@param curve {time: number, end_time: number, difficulty: number}[]?
function PatternStrip:setSections(sections, curve)
	self.sections = sections and #sections > 0 and sections or nil
	self.summary = ""
	self.parts = {}
	if not self.sections then
		return
	end
	local count = {} ---@type {[string]: integer}
	local weight = {} ---@type {[string]: number}
	local bpms = {} ---@type {[string]: number[]}
	local difficulties = {} ---@type {[string]: number[]}
	for _, sec in ipairs(self.sections) do
		local section_difficulty = PatternStrip.sectionDifficulty(curve, sec.time, sec.time + pattern_classifier.WINDOW)
		for l, v in pairs(sec.labels) do
			if v >= 0.5 then
				count[l] = (count[l] or 0) + 1
				weight[l] = (weight[l] or 0) + section_difficulty
				bpms[l] = bpms[l] or {}
				table.insert(bpms[l], sec.bpm)
				difficulties[l] = difficulties[l] or {}
				table.insert(difficulties[l], section_difficulty)
			end
		end
	end
	local patterns = {} ---@type string[]
	for l in pairs(count) do
		if not IS_SKILLSET[l] then table.insert(patterns, l) end
	end
	table.sort(patterns, function(a, b)
		local wa, wb = weight[a] or 0, weight[b] or 0
		return wa > wb or wa == wb and count[a] > count[b] or wa == wb and count[a] == count[b] and a < b
	end)
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
		local ds = difficulties[l]
		local difficulty ---@type number?
		if ds and #ds > 0 then
			local sum = 0
			for _, d in ipairs(ds) do sum = sum + d end
			difficulty = sum / #ds
		end
		table.insert(self.parts, {
			label = l,
			share = share,
			bpm = bpm,
			difficulty = difficulty,
			text = text,
			skillset = IS_SKILLSET[l] or false,
		})
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

---@param seconds number
---@return string
local function format_time(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

---The chart time ranges where a label scores at least threshold, overlapping sections merged.
---@param sections chart.scoring.pattern_classifier.Section[]
---@param label string
---@param threshold number
---@return {start: number, stop: number, score: number}[]
function PatternStrip.occurrences(sections, label, threshold)
	local ranges = {} ---@type {start: number, stop: number, score: number}[]
	for _, sec in ipairs(sections) do
		local score = sec.labels[label]
		if score and score >= threshold then
			local stop = sec.time + pattern_classifier.WINDOW
			local last = ranges[#ranges]
			if last and sec.time <= last.stop then
				last.stop = math.max(last.stop, stop)
				last.score = math.max(last.score, score)
			else
				table.insert(ranges, {start = sec.time, stop = stop, score = score})
			end
		end
	end
	return ranges
end

---Selects the row under a screen point, or clears the selection when it is the selected one again.
---@param screen_x number
---@param screen_y number
---@return boolean handled
function PatternStrip:selectAt(screen_x, screen_y)
	local _, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	for _, row in ipairs(self.row_bounds or {}) do
		if y >= row.y and y < row.y + row.h then
			self.debug_label = self.debug_label == row.label and nil or row.label
			return true
		end
	end
	return false
end

---The height of a part's bar: its difficulty relative to the hardest part, cubed so the difference reads more strongly.
---@param difficulty number?
---@param max_difficulty number
---@param row_h number
---@return number
function PatternStrip.barHeight(difficulty, max_difficulty, row_h)
	if max_difficulty <= 0 then
		return row_h
	end
	return row_h * ((difficulty or 0) / max_difficulty) ^ 3
end

function PatternStrip:draw()
	self.row_bounds = {}
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
	local share_w, bpm_w, diff_w = big:getWidth("100%"), big:getWidth("000 BPM"), big:getWidth("00.0")
	local width = PAD * 2 + ROW_PAD * 2 + name_w + GAP + share_w + GAP + bpm_w + GAP + diff_w
	local row_h = big:getHeight() + 8
	local small_row = small:getHeight() + 2
	local n_patterns = #self.parts - #SKILLSETS
	local height = PAD * 2 + #SKILLSETS * (row_h + 4) - 4 + (n_patterns > 0 and 13 + n_patterns * small_row or 0)

	lg.setColor(PANEL_COLOR)
	lg.rectangle("fill", 0, 0, width, height)
	local inner = width - PAD * 2
	local left, right = PAD + ROW_PAD, width - PAD - ROW_PAD
	local diff_x = right
	local bpm_x = right - diff_w - GAP
	local share_x = bpm_x - bpm_w - GAP
	local max_difficulty = 0
	for _, part in ipairs(self.parts) do
		max_difficulty = math.max(max_difficulty, part.difficulty or 0)
	end
	local y = PAD
	for i, part in ipairs(self.parts) do
		local bpm = part.bpm and ("%d BPM"):format(part.bpm + 0.5) or "-"
		local share = ("%d%%"):format(part.share * 100 + 0.5)
		local difficulty = part.difficulty and ("%.1f"):format(part.difficulty) or "-"
		if part.skillset then
			local color = COLORS[part.label]
			local alpha = part.share > 0 and 1 or 0.45
			lg.setColor(1, 1, 1, 0.05)
			lg.rectangle("fill", PAD, y, inner, row_h)
			local bar_h = PatternStrip.barHeight(part.difficulty, max_difficulty, row_h)
			lg.setColor(color[1], color[2], color[3], 0.45)
			lg.rectangle("fill", PAD, y + (row_h - bar_h) / 2, inner * part.share, bar_h)
			local ty = y + 4
			lg.setFont(self.bold_font)
			lg.setColor(color[1], color[2], color[3], alpha)
			lg.print(part.label, left, ty)
			lg.setFont(big)
			lg.setColor(1, 1, 1, 0.95 * alpha)
			print_right(share, share_x, ty)
			lg.setColor(1, 1, 1, 0.55 * alpha)
			print_right(bpm, bpm_x, ty)
			print_right(difficulty, diff_x, ty)
			table.insert(self.row_bounds, {label = part.label, y = y, h = row_h})
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
			print_right(bpm, bpm_x, y)
			print_right(difficulty, diff_x, y)
			table.insert(self.row_bounds, {label = part.label, y = y, h = small_row})
			y = y + small_row
		end
	end

	-- debug: click a row to see where its label is in the chart
	if self.debug_label and self.sections then
		local ranges = PatternStrip.occurrences(self.sections, self.debug_label, 0.5)
		local text = (self.debug_label:gsub("_", " ")) .. ": "
		if #ranges == 0 then
			text = text .. "nowhere"
		else
			local parts = {}
			for _, range in ipairs(ranges) do
				table.insert(parts, ("%s-%s (%.2f)"):format(format_time(range.start), format_time(range.stop), range.score))
			end
			text = text .. table.concat(parts, "  ")
		end
		lg.setFont(small)
		lg.setColor(1, 1, 1, 0.75)
		lg.printf(text, PAD, height + 8, math.max(1, self.width - PAD * 2))
	end
end

return PatternStrip
