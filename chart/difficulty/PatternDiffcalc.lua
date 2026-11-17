local IDiffcalc = require("chart.difficulty.IDiffcalc")
local pattern_classifier = require("chart.scoring.pattern_classifier")
local RizuDifficulty = require("rizu.library.RizuDifficulty")

---@class chart.PatternDiffcalc: chart.IDiffcalc
---@operator call: chart.PatternDiffcalc
local PatternDiffcalc = IDiffcalc + {}

PatternDiffcalc.name = "patterns"
PatternDiffcalc.chartdiff_field = "skillset"

-- A section fits a pattern at this label score or above.
local threshold = 0.5
-- A label's hardness is its difficulty times share / (share + this), so a short pattern is not made to look hard.
local share_offset = 0.05
-- A section's difficulty is this percentile of the Rizu curve inside it, to keep spikes.
local SECTION_QUANTILE = 0.9

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
			hardness = difficulty * share / (share + share_offset),
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
			if score >= threshold then
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

---@param ctx chart.DiffcalcContext
function PatternDiffcalc:compute(ctx)
	local inputmode = tostring(ctx.chart.inputMode)
	if not pattern_classifier.canAnalyze(inputmode) then
		return
	end
	local notes = ctx:getSimplifiedNotes()
	local sections = pattern_classifier.analyze(notes, inputmode)
	if not sections or #sections == 0 then
		return
	end

	local difficulties = {} ---@type number[]
	local curve = RizuDifficulty.rateCurve(notes, inputmode)
	for i, sec in ipairs(sections) do
		difficulties[i] = section_difficulty(curve, sec.time, sec.time + pattern_classifier.WINDOW)
	end

	local skillset = ranked(skillset_stats(sections, difficulties))[1]
	local stats = pattern_stats(sections, difficulties)
	local labels = ranked(stats)
	if not skillset or not labels[1] then
		return
	end

	local chartdiff = ctx.chartdiff
	chartdiff.skillset = skillset
	chartdiff.pattern_1 = labels[1]
	chartdiff.pattern_share_1 = stats[labels[1]].share
	chartdiff.pattern_bpm_1 = stats[labels[1]].bpm
	if labels[2] then
		chartdiff.pattern_2 = labels[2]
		chartdiff.pattern_share_2 = stats[labels[2]].share
		chartdiff.pattern_bpm_2 = stats[labels[2]].bpm
	end
end

return PatternDiffcalc
