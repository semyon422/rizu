local DifficultyModel = require("chart.difficulty.DifficultyModel")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local PatternDiffcalc = require("chart.difficulty.PatternDiffcalc")
local pattern_classifier = require("chart.scoring.pattern_classifier")
local Pattern = require("chart.scoring.Pattern")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

-- Rows on a 1/4 grid at a BPM for 12 s, columns from a list of rows repeated in order.
---@param bpm number
---@param pattern integer[][]
---@return table[]
local function chart(bpm, pattern)
	local notes = {}
	local dt = 15 / bpm
	local i = 0
	while i * dt < 12 do
		for _, column in ipairs(pattern[i % #pattern + 1]) do
			table.insert(notes, {time = i * dt, column = column})
		end
		i = i + 1
	end
	return notes
end

---@param t testing.T
function test.classifies_patterns(t)
	local source = TestChartFactory():create("4key", chart(180, {{1}, {3}, {2}, {4}}))
	local chartdiff = source.chartdiff
	DifficultyModel():compute(chartdiff, source.chart, 1)

	t:assert(chartdiff.skillset == "speed" or chartdiff.skillset == "stamina"
		or chartdiff.skillset == "jacks" or chartdiff.skillset == "technical", chartdiff.skillset)
	t:assert(chartdiff.pattern_1, "a pattern")
	t:assert(chartdiff.pattern_1 ~= "speed" and chartdiff.pattern_1 ~= "stamina"
		and chartdiff.pattern_1 ~= "jacks" and chartdiff.pattern_1 ~= "technical", chartdiff.pattern_1)
	t:assert(chartdiff.pattern_share_1 and chartdiff.pattern_share_1 > 0 and chartdiff.pattern_share_1 <= 1, chartdiff.pattern_share_1)
	t:assert(math.abs(chartdiff.pattern_bpm_1 - 180) < 0.01, chartdiff.pattern_bpm_1)
end

---@param t testing.T
function test.no_patterns_for_keymodes_without_a_model(t)
	local source = TestChartFactory():create("5key", chart(180, {{1}, {3}, {2}, {4}, {5}}))
	local chartdiff = source.chartdiff
	DifficultyModel():compute(chartdiff, source.chart, 1)
	t:eq(chartdiff.skillset, nil)
end

---@param t testing.T
function test.no_patterns_for_a_bogus_span(t)
	local source = TestChartFactory():create("4key", {
		{time = -2147483.648, column = 1},
		{time = 23, column = 2},
	})
	local chartdiff = source.chartdiff
	PatternDiffcalc:compute(DiffcalcContext(chartdiff, source.chart, 1))

	t:eq(chartdiff.skillset, nil)
	t:eq(chartdiff.pattern_1, nil)
	t:eq(chartdiff.pattern_bpm_1, nil)
end

---@param t testing.T
function test.every_model_label_has_a_pattern_id(t)
	local is_skillset = {} ---@type {[string]: true}
	for _, label in ipairs(pattern_classifier.SKILLSETS) do
		is_skillset[label] = true
	end
	for _, name in ipairs({"chart.scoring.pattern_classifier_4k", "chart.scoring.pattern_classifier_7k"}) do
		local model = require(name) --[[@as chart.scoring.pattern_classifier.Model]]
		for _, label in ipairs(model.labels) do
			if not is_skillset[label] then
				t:ne(Pattern:encode_safe(label), nil, name .. " labels " .. label)
			end
		end
	end
end

return test
