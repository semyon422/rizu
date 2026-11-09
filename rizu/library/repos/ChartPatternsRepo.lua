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

---The top skillset and the two most significant patterns of a chartdiff.
---@class rizu.library.ChartPatterns
---@field skillset string
---@field patterns rizu.library.ChartPattern[] most significant first, at most two

---The few most significant patterns of a chartdiff and its top skillset, classified from its notes preview and
---cached in chart_patterns.
---@class rizu.library.repos.ChartPatternsRepo
---@operator call: rizu.library.repos.ChartPatternsRepo
local ChartPatternsRepo = class()

-- Raise it when the classifier or the aggregation changes, so the patterns are made again.
ChartPatternsRepo.revision = 2
ChartPatternsRepo.max_patterns = 2
-- A section fits a pattern at this label score or above.
ChartPatternsRepo.threshold = 0.5
-- A label's hardness is its difficulty times share / (share + this), so a short pattern is not made to look hard.
ChartPatternsRepo.share_offset = 0.05
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

---@param values number[]?
---@return number?
local function median(values)
	if not values or #values == 0 then
		return
	end
	table.sort(values)
	return values[math.ceil(#values / 2)]
end

---@param count {[string]: integer}
---@param difficulty_sum {[string]: number}
---@param bpms {[string]: number[]}
---@param total integer
---@return {[string]: {share: number, difficulty: number, hardness: number, bpm: number?}}
local function finalize(count, difficulty_sum, bpms, total)
	---@type {[string]: {share: number, difficulty: number, hardness: number, bpm: number?}}
	local stats = {}
	for label, c in pairs(count) do
		local share = c / total
		local difficulty = difficulty_sum[label] / c
		stats[label] = {
			share = share,
			difficulty = difficulty,
			hardness = difficulty * share / (share + ChartPatternsRepo.share_offset),
			bpm = median(bpms[label]),
		}
	end
	return stats
end

---Sections vote for their highest-scoring skillset.
---@param sections chart.scoring.pattern_classifier.Section[]
---@param difficulties number[]
---@return {[string]: {share: number, difficulty: number, hardness: number, bpm: number?}}
local function skillset_stats(sections, difficulties)
	---@type {[string]: integer}, {[string]: number}
	local count, difficulty_sum = {}, {}
	for i, sec in ipairs(sections) do
		local best, value = nil, -math.huge
		for _, label in ipairs(pattern_classifier.SKILLSETS) do
			local score = sec.skillsets[label]
			if score and score > value then
				best, value = label, score
			end
		end
		if best then
			count[best] = (count[best] or 0) + 1
			difficulty_sum[best] = (difficulty_sum[best] or 0) + difficulties[i]
		end
	end
	return finalize(count, difficulty_sum, {}, #sections)
end

---@param sections chart.scoring.pattern_classifier.Section[]
---@param difficulties number[]
---@return {[string]: {share: number, difficulty: number, hardness: number, bpm: number?}}
local function pattern_stats(sections, difficulties)
	---@type {[string]: integer}, {[string]: number}, {[string]: number[]}
	local count, difficulty_sum, bpms = {}, {}, {}
	for i, sec in ipairs(sections) do
		for label, score in pairs(sec.patterns) do
			if score >= ChartPatternsRepo.threshold then
				count[label] = (count[label] or 0) + 1
				difficulty_sum[label] = (difficulty_sum[label] or 0) + difficulties[i]
				if sec.bpm then
					bpms[label] = bpms[label] or {}
					table.insert(bpms[label], sec.bpm)
				end
			end
		end
	end
	return finalize(count, difficulty_sum, bpms, #sections)
end

---@param stats {[string]: {share: number, difficulty: number, hardness: number, bpm: number?}}
---@return string[]
local function ranked(stats)
	local labels = {} ---@type string[]
	for label in pairs(stats) do
		table.insert(labels, label)
	end
	table.sort(labels, function(a, b)
		if stats[a].hardness ~= stats[b].hardness then
			return stats[a].hardness > stats[b].hardness
		end
		if stats[a].share ~= stats[b].share then
			return stats[a].share > stats[b].share
		end
		return a < b
	end)
	return labels
end

---The hardest skillset and the patterns with the highest hardness, up to max_patterns.
---@param sections chart.scoring.pattern_classifier.Section[]
---@param curve {time: number, end_time: number, difficulty: number}[]?
---@return rizu.library.ChartPatterns?
local function aggregate(sections, curve)
	if #sections == 0 then
		return
	end
	local difficulties = {} ---@type number[]
	for i, sec in ipairs(sections) do
		difficulties[i] = section_difficulty(curve, sec.time, sec.time + pattern_classifier.WINDOW)
	end

	local skillsets = skillset_stats(sections, difficulties)
	local skillset = ranked(skillsets)[1]
	local patterns = pattern_stats(sections, difficulties)
	local labels = ranked(patterns)

	---@type rizu.library.ChartPattern[]
	local rows = {}
	for rank = 1, math.min(#labels, ChartPatternsRepo.max_patterns) do
		local label = labels[rank]
		local stat = patterns[label]
		rows[rank] = {rank = rank, pattern = label, share = stat.share, bpm = stat.bpm}
	end
	if not skillset or not rows[1] then
		return
	end
	return {skillset = skillset, patterns = rows}
end

---The chartdiff's patterns, or nil for charts the classifier does not read.
---@param chartdiff sea.Chartdiff
---@return rizu.library.ChartPatterns?
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

---The cached patterns of a chartdiff, or nil when they are missing or of an older version.
---@param chartdiff_id integer
---@return rizu.library.ChartPatterns?
function ChartPatternsRepo:get(chartdiff_id)
	local row = self.models.chart_patterns:find(
		{chartdiff_id = assert(chartdiff_id), version = ChartPatternsRepo.getVersion()}
	)
	if not row then
		return
	end
	---@type rizu.library.ChartPattern[]
	local patterns = {
		{rank = 1, pattern = row.pattern_1, share = row.share_1, bpm = row.bpm_1},
	}
	if row.pattern_2 then
		patterns[2] = {rank = 2, pattern = row.pattern_2, share = row.share_2, bpm = row.bpm_2}
	end
	return {skillset = row.skillset, patterns = patterns}
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
---@param patterns rizu.library.ChartPatterns?
function ChartPatternsRepo:saveComputed(chartdiff, patterns)
	if not patterns or not patterns.patterns[1] then
		return
	end
	local chartdiff_id = assert(chartdiff.id, "chartdiff without an id")
	if self.models.chart_patterns:count({chartdiff_id = chartdiff_id, version = ChartPatternsRepo.getVersion()}) > 0 then
		return
	end

	self.models.chart_patterns:delete({chartdiff_id = chartdiff_id})

	local first = patterns.patterns[1]
	local second = patterns.patterns[2]
	self.models.chart_patterns:create({
		chartdiff_id = chartdiff_id,
		version = ChartPatternsRepo.getVersion(),
		skillset = patterns.skillset,
		pattern_1 = first.pattern,
		pattern_2 = second and second.pattern or nil,
		share_1 = first.share,
		share_2 = second and second.share or nil,
		bpm_1 = first.bpm,
		bpm_2 = second and second.bpm or nil,
	})
end

return ChartPatternsRepo
