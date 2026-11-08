local class = require("class")
local InputMode = require("chart.core.InputMode")
local NotesPreview = require("rizu.preview.NotesPreview")
local pattern_classifier = require("chart.scoring.pattern_classifier")
local RizuDifficulty = require("rizu.library.RizuDifficulty")

---One pattern of a chartdiff.
---@class rizu.library.ChartPattern
---@field rank integer most significant is 1
---@field pattern string
---@field share number fraction of the chart's sections it fits
---@field bpm number? median BPM of those sections

---The few most significant patterns of a chartdiff, classified from its notes preview and cached in chart_patterns.
---@class rizu.library.repos.ChartPatternsRepo
---@operator call: rizu.library.repos.ChartPatternsRepo
local ChartPatternsRepo = class()

-- Raise it when the classifier or the aggregation changes, so the patterns are made again.
ChartPatternsRepo.revision = 1
ChartPatternsRepo.max_patterns = 3
-- A section fits a pattern at this label score or above.
ChartPatternsRepo.threshold = 0.5
-- A section's difficulty is this percentile of the Rizu curve inside it, to keep spikes.
local SECTION_QUANTILE = 0.9

---@param models rdb.Models
function ChartPatternsRepo:new(models)
	self.models = models
end

---The version of the patterns a run makes. Rizu Difficulty's curve orders them, so its version is part of it:
---raising it makes every pattern again, like it makes every difficulty value again. Below 1000, a revision
---cannot collide with the next difficulty version.
---@return integer
function ChartPatternsRepo.getVersion()
	return RizuDifficulty.version * 1000 + ChartPatternsRepo.revision
end

---The 90th percentile of the Rizu curve inside a section, or 1 without a curve so patterns count equally.
---@param curve {time: number, end_time: number, difficulty: number}[]?
---@param start number
---@param stop number
---@return number
local function section_difficulty(curve, start, stop)
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

---The patterns that fit the most sections, the hardest sections first, up to max_patterns.
---@param sections chart.scoring.pattern_classifier.Section[]
---@param curve {time: number, end_time: number, difficulty: number}[]?
---@return rizu.library.ChartPattern[]
local function aggregate(sections, curve)
	---@type {[string]: integer}, {[string]: number}, {[string]: number[]}
	local count, weight, bpms = {}, {}, {}
	for _, sec in ipairs(sections) do
		local difficulty = section_difficulty(curve, sec.time, sec.time + pattern_classifier.WINDOW)
		for label, score in pairs(sec.patterns) do
			if score >= ChartPatternsRepo.threshold then
				count[label] = (count[label] or 0) + 1
				weight[label] = (weight[label] or 0) + difficulty
				if sec.bpm then
					bpms[label] = bpms[label] or {}
					table.insert(bpms[label], sec.bpm)
				end
			end
		end
	end

	local patterns = {} ---@type string[]
	for label in pairs(count) do
		table.insert(patterns, label)
	end
	table.sort(patterns, function(a, b)
		if weight[a] ~= weight[b] then
			return weight[a] > weight[b]
		end
		if count[a] ~= count[b] then
			return count[a] > count[b]
		end
		return a < b
	end)

	---@type rizu.library.ChartPattern[]
	local rows = {}
	for rank = 1, math.min(#patterns, ChartPatternsRepo.max_patterns) do
		local pattern = patterns[rank]
		local b = bpms[pattern]
		local bpm ---@type number?
		if b then
			table.sort(b)
			bpm = b[math.ceil(#b / 2)]
		end
		rows[rank] = {rank = rank, pattern = pattern, share = count[pattern] / #sections, bpm = bpm}
	end
	return rows
end

---The chartdiff's patterns, or nil for charts the classifier does not read.
---@param chartdiff sea.Chartdiff
---@return rizu.library.ChartPattern[]?
function ChartPatternsRepo.compute(chartdiff)
	if chartdiff.mode ~= "mania" or not chartdiff.notes_preview or chartdiff.notes_preview == "" then
		return
	end
	local inputmode = chartdiff.inputmode
	local ok, notes = pcall(NotesPreview.getNotes, chartdiff.notes_preview, InputMode(inputmode):getColumns())
	if not ok then
		return
	end
	local sections = pattern_classifier.analyze(notes, inputmode)
	if not sections then
		return
	end
	return aggregate(sections, RizuDifficulty.rateCurve(notes, inputmode))
end

---The cached patterns of a chartdiff, the most significant first.
---@param chartdiff_id integer
---@return rizu.library.ChartPattern[]
function ChartPatternsRepo:get(chartdiff_id)
	return self.models.chart_patterns:select(
		{chartdiff_id = assert(chartdiff_id), version = ChartPatternsRepo.getVersion()},
		{order = {"rank ASC"}}
	) --[[@as rizu.library.ChartPattern[] ]]
end

---Chartdiffs whose patterns are missing or of an older version.
---@return sea.Chartdiff[]
function ChartPatternsRepo:getMissingChartdiffs()
	local sql = ([[
NOT EXISTS (
	SELECT 1 FROM chart_patterns
	WHERE chart_patterns.chartdiff_id = chartdiffs.id AND chart_patterns.version = %d
)]]):format(ChartPatternsRepo.getVersion())
	---@type rdb.Conditions
	local conditions = {}
	---@diagnostic disable-next-line: no-unknown -- a raw SQL condition, as rdb.Conditions allows
	conditions[{sql}] = true
	return self.models.chartdiffs:select(conditions)
end

---Caches the chartdiff's patterns, replacing them when they are missing or of an older version.
---@param chartdiff sea.Chartdiff
function ChartPatternsRepo:save(chartdiff)
	local chartdiff_id = assert(chartdiff.id, "chartdiff without an id")
	if self.models.chart_patterns:count({chartdiff_id = chartdiff_id, version = ChartPatternsRepo.getVersion()}) > 0 then
		return
	end
	self:saveComputed(chartdiff, ChartPatternsRepo.compute(chartdiff))
end

---Caches patterns classified earlier, e.g. when the chart was loaded to play it.
---@param chartdiff sea.Chartdiff
---@param patterns rizu.library.ChartPattern[]?
function ChartPatternsRepo:saveComputed(chartdiff, patterns)
	if not patterns or not patterns[1] then
		return
	end
	local chartdiff_id = assert(chartdiff.id, "chartdiff without an id")
	if self.models.chart_patterns:count({chartdiff_id = chartdiff_id, version = ChartPatternsRepo.getVersion()}) > 0 then
		return
	end

	self.models.chart_patterns:delete({chartdiff_id = chartdiff_id})

	---@type {chartdiff_id: integer, rank: integer, pattern: string, share: number, bpm: number?, version: integer}[]
	local rows = {}
	for _, p in ipairs(patterns) do
		table.insert(rows, {
			chartdiff_id = chartdiff_id,
			rank = p.rank,
			pattern = p.pattern,
			share = p.share,
			bpm = p.bpm,
			version = ChartPatternsRepo.getVersion(),
		})
	end
	self.models.chart_patterns:insert(rows)
end

return ChartPatternsRepo
