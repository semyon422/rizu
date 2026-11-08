local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ChartPatternsRepo = require("rizu.library.repos.ChartPatternsRepo")
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
---@return table[]
local function patterns(repo, chartdiff)
	return repo.models.chart_patterns:select({chartdiff_id = chartdiff.id}, {order = {"rank ASC"}})
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
	local rows = patterns(repo, chartdiff)
	t:assert(#rows >= 1 and #rows <= ChartPatternsRepo.max_patterns, #rows)
	for i, row in ipairs(rows) do
		t:eq(row.rank, i)
		t:eq(row.version, ChartPatternsRepo.getVersion())
		t:assert(row.share > 0 and row.share <= 1, row.pattern)
		t:assert(row.pattern ~= "speed" and row.pattern ~= "stamina" and row.pattern ~= "jacks" and row.pattern ~= "technical")
	end
	t:assert(math.abs(rows[1].bpm - 180) < 0.01, rows[1].bpm)

	local cached = repo:get(chartdiff.id)
	t:eq(#cached, #rows)
	t:eq(cached[1].pattern, rows[1].pattern)

	-- A save of the same patterns replaces them, it does not add to them.
	repo:save(chartdiff)
	t:eq(#patterns(repo, chartdiff), #rows)

	db.models.chartdiffs:delete({id = chartdiff.id})
	t:eq(#patterns(repo, chartdiff), 0, "patterns follow the chartdiff")
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
	t:eq(#patterns(repo, chartdiff), 0, "nothing to store")

	repo:saveComputed(chartdiff, {{rank = 1, pattern = "stream", share = 0.5, bpm = 180}})
	local rows = patterns(repo, chartdiff)
	t:eq(#rows, 1)
	t:eq(rows[1].pattern, "stream")

	-- Current patterns are not replaced.
	repo:saveComputed(chartdiff, {{rank = 1, pattern = "jacks", share = 1, bpm = 120}})
	t:eq(patterns(repo, chartdiff)[1].pattern, "stream")
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
	t:eq(#repo:get(chartdiff.id), 0, "patterns of an older version are not shown")
	t:tdeq(missing_ids(repo), {chartdiff.id}, "and they are made again")
	repo:save(chartdiff)
	for _, row in ipairs(patterns(repo, chartdiff)) do
		t:eq(row.version, ChartPatternsRepo.getVersion())
	end
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
	t:eq(#patterns(repo, chartdiff), 0)
	db:unload()
end

return test
