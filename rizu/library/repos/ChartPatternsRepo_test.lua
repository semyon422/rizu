local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ChartPatternsRepo = require("rizu.library.repos.ChartPatternsRepo")
local pattern_classifier = require("chart.scoring.pattern_classifier")
local Pattern = require("chart.scoring.Pattern")
local TestChartFactory = require("sea.chart.TestChartFactory")
local PreviewDiffcalc = require("chart.difficulty.PreviewDiffcalc")

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

---@param repo rizu.library.repos.ChartPatternsRepo
---@param chartdiff sea.Chartdiff
---@return table?
local function row(repo, chartdiff)
	return repo.models.chart_patterns:find({chartdiff_id = chartdiff.id})
end

---@param repo rizu.library.repos.ChartPatternsRepo
---@return integer[]
local function missing_ids(repo)
	local ids = {}
	for _, chartdiff in ipairs(repo:getMissingChartdiffs()) do
		table.insert(ids, chartdiff.id)
	end
	return ids
end

---@param t testing.T
function test.saves_the_most_significant_patterns(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local chartsRepo = ChartsRepo(db.models, {})
	local repo = ChartPatternsRepo(db.models)

	local source = TestChartFactory():create("4key", chart(180, {{1}, {3}, {2}, {4}}))
	PreviewDiffcalc:compute({chart = source.chart, chartdiff = source.chartdiff})
	local chartdiff = chartsRepo:createChartdiff(source.chartdiff)

	repo:save(chartdiff)
	local saved = assert(row(repo, chartdiff))
	t:eq(saved.version, ChartPatternsRepo.getVersion())
	t:assert(saved.skillset == "speed" or saved.skillset == "stamina" or saved.skillset == "jacks" or saved.skillset == "technical", saved.skillset)
	t:assert(saved.share_1 > 0 and saved.share_1 <= 1, saved.pattern_1)
	t:assert(saved.pattern_1 ~= "speed" and saved.pattern_1 ~= "stamina" and saved.pattern_1 ~= "jacks" and saved.pattern_1 ~= "technical")
	t:assert(math.abs(saved.bpm_1 - 180) < 0.01, saved.bpm_1)

	local cached = assert(repo:get(chartdiff.id))
	t:eq(cached.skillset, saved.skillset)
	t:eq(cached.patterns[1].pattern, saved.pattern_1)
	t:eq(cached.patterns[1].share, saved.share_1)

	-- A save of the same patterns replaces them, it does not add to them.
	repo:save(chartdiff)
	t:eq(db.models.chart_patterns:count({chartdiff_id = chartdiff.id}), 1)

	db.models.chartdiffs:delete({id = chartdiff.id})
	t:eq(row(repo, chartdiff), nil, "patterns follow the chartdiff")
	db:unload()
end

---@param t testing.T
function test.saves_patterns_classified_earlier(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local chartsRepo = ChartsRepo(db.models, {})
	local repo = ChartPatternsRepo(db.models)

	local source = TestChartFactory():create("4key", chart(180, {{1}, {3}, {2}, {4}}))
	PreviewDiffcalc:compute({chart = source.chart, chartdiff = source.chartdiff})
	local chartdiff = chartsRepo:createChartdiff(source.chartdiff)

	repo:saveComputed(chartdiff, nil)
	t:eq(row(repo, chartdiff), nil, "nothing to store")

	repo:saveComputed(chartdiff, {
		skillset = "jacks",
		patterns = {{rank = 1, pattern = "stream", share = 0.5, bpm = 180}},
	})
	local saved = assert(row(repo, chartdiff))
	t:eq(saved.skillset, "jacks")
	t:eq(saved.pattern_1, "stream")
	t:eq(saved.pattern_2, nil)

	-- Current patterns are not replaced.
	repo:saveComputed(chartdiff, {
		skillset = "technical",
		patterns = {{rank = 1, pattern = "jacks", share = 1, bpm = 120}},
	})
	t:eq(assert(row(repo, chartdiff)).pattern_1, "stream")
	db:unload()
end

---@param t testing.T
function test.remakes_patterns_of_an_older_version(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local chartsRepo = ChartsRepo(db.models, {})
	local repo = ChartPatternsRepo(db.models)

	local source = TestChartFactory():create("4key", chart(180, {{1}, {3}, {2}, {4}}))
	PreviewDiffcalc:compute({chart = source.chart, chartdiff = source.chartdiff})
	local chartdiff = chartsRepo:createChartdiff(source.chartdiff)

	t:tdeq(missing_ids(repo), {chartdiff.id})
	repo:save(chartdiff)
	t:tdeq(missing_ids(repo), {})

	db.models.chart_patterns:update({version = ChartPatternsRepo.getVersion() - 1}, {chartdiff_id = chartdiff.id})
	t:eq(repo:get(chartdiff.id), nil, "patterns of an older version are not shown")
	t:tdeq(missing_ids(repo), {chartdiff.id}, "and they are made again")
	repo:save(chartdiff)
	t:eq(assert(row(repo, chartdiff)).version, ChartPatternsRepo.getVersion())
	db:unload()
end

---@param t testing.T
function test.no_patterns_for_keymodes_without_a_model(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local chartsRepo = ChartsRepo(db.models, {})
	local repo = ChartPatternsRepo(db.models)

	local source = TestChartFactory():create("5key", chart(180, {{1}, {3}, {2}, {4}, {5}}))
	PreviewDiffcalc:compute({chart = source.chart, chartdiff = source.chartdiff})
	local chartdiff = chartsRepo:createChartdiff(source.chartdiff)

	repo:save(chartdiff)
	t:eq(row(repo, chartdiff), nil)
	db:unload()
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
