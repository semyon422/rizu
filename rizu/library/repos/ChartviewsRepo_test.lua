local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local ChartviewsRepo = require("rizu.library.repos.ChartviewsRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

local function setup()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")

	local factory = TestChartFactory()

	-- Insert location
	db.models.locations:create({
		id = 1, name = "Test", path = "/test", is_relative = 0, is_internal = 0,
	})

	-- Set 1: Multiple files
	db.models.chartfile_sets:create({ id = 1, location_id = 1, name = "Set 1", dir = "s1", modified_at = 0, is_file = 0 })
	-- File 1: Multiple metas
	db.models.chartfiles:create({ id = 1, set_id = 1, name = "f1.osu", hash = "h1", modified_at = 0 })
	db.models.chartmetas:create(factory:createChartmeta({ id = 1, hash = "h1", index = 1, inputmode = "4key" }))
	db.models.chartmetas:create(factory:createChartmeta({ id = 2, hash = "h1", index = 2, inputmode = "7key" }))
	-- File 2: Single meta
	db.models.chartfiles:create({ id = 2, set_id = 1, name = "f2.osu", hash = "h2", modified_at = 0 })
	db.models.chartmetas:create(factory:createChartmeta({ id = 3, hash = "h2", index = 1, inputmode = "4key" }))

	-- Set 2: Single file, single meta, multiple diffs, multiple plays
	db.models.chartfile_sets:create({ id = 2, location_id = 1, name = "Set 2", dir = "s2", modified_at = 0, is_file = 0 })
	db.models.chartfiles:create({ id = 3, set_id = 2, name = "f3.osu", hash = "h3", modified_at = 0 })
	db.models.chartmetas:create(factory:createChartmeta({ id = 4, hash = "h3", index = 1, inputmode = "4key" }))
	
	-- Meta 4: Two diffs
	db.models.chartdiffs:create(factory:createChartdiff({ id = 1, hash = "h3", index = 1, rate = 1.0, enps_diff = 10 }))
	db.models.chartdiffs:create(factory:createChartdiff({ id = 2, hash = "h3", index = 1, rate = 1.2, enps_diff = 12 }))
	
	-- Diff 1: Two plays
	db.models.chartplays:create(factory:createChartplay({ id = 1, hash = "h3", index = 1, rate = 1.0, accuracy = 0.90, created_at = 100 }))
	db.models.chartplays:create(factory:createChartplay({ id = 2, hash = "h3", index = 1, rate = 1.0, accuracy = 0.95, created_at = 200 }))
	-- Diff 2: One play
	db.models.chartplays:create(factory:createChartplay({ id = 3, hash = "h3", index = 1, rate = 1.2, accuracy = 0.98, created_at = 300 }))

	local repo = ChartviewsRepo(db.models)
	repo:setSync(true)
	repo.params = { difficulty = "enps_diff", where = {} }

	return db, repo, factory
end

local function setup_root_set()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")

	local factory = TestChartFactory()
	db.models.locations:create({
		id = 1, name = "Test", path = "/test", is_relative = 0, is_internal = 0,
	})
	db.models.chartfile_sets:create({
		id = 1, location_id = 1, name = "Root Set", modified_at = 0, is_file = false,
	})
	db.models.chartfiles:create({
		id = 1, set_id = 1, name = "root.osu", hash = "root", modified_at = 0,
	})
	db.models.chartmetas:create(factory:createChartmeta({
		id = 1, hash = "root", index = 1, inputmode = "4key",
	}))

	local repo = ChartviewsRepo(db.models)
	repo:setSync(true)
	repo.params = {
		primary_mode = "chartmetas",
		secondary_mode = "chartmetas",
		difficulty = "enps_diff",
		where = {},
	}
	return db, repo
end

local function setup_partial_cache()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")

	db.models.locations:create({
		id = 1, name = "Test", path = "/test", is_relative = 0, is_internal = 0,
	})
	db.models.chartfile_sets:create({
		id = 1, location_id = 1, name = "Set 1", dir = "s1", modified_at = 0, is_file = 0,
	})
	db.models.chartfiles:create({
		id = 1, set_id = 1, name = "f1.osu", modified_at = 0,
	})

	local repo = ChartviewsRepo(db.models)
	repo:setSync(true)
	repo.params = {difficulty = "enps_diff", where = {}}

	return db, repo
end

---@param t testing.T
function test.root_set_path(t)
	local db, repo = setup_root_set()
	local chartview = repo:getChartview({
		chartfile_id = 1,
		chartmeta_id = 1,
	})
	---@cast chartview -?

	t:eq(chartview.dir, "Root Set")
	t:eq(chartview.path, "Root Set/root.osu")

	db:unload()
end

---@param t testing.T
function test.primary_modes(t)
	local db, repo = setup()

	local function count(mode)
		repo.params.primary_mode = mode
		local res = repo:query()
		return res.count
	end

	t:eq(count("chartfile_sets"), 2, "Sets mode: Set 1, Set 2")
	t:eq(count("chartfiles"), 3, "Files mode: f1, f2, f3")
	t:eq(count("chartmetas"), 4, "Metas mode: m1, m2 (in f1), m3 (in f2), m4 (in f3)")
	t:eq(count("chartdiffs"), 5, "Diffs mode: m1-d1, m2-d1, m3-d1, m4-d1, m4-d2")
	t:eq(count("chartplays"), 3, "Plays mode: p1, p2, p3 (Note: chartplays level is INNER JOIN, only Set 2 has plays in this setup)")

	db:unload()
end

---@param t testing.T
function test.partial_cache_primary_modes(t)
	local db, repo = setup_partial_cache()

	local function query(mode)
		repo.params.primary_mode = mode
		repo.params.secondary_mode = "chartmetas"
		return repo:query()
	end

	for _, mode in ipairs({"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs"}) do
		local res = query(mode)
		t:eq(res.count, 1, mode .. " should include scanned chartfiles before hashing finishes")

		local items = repo:unpackResult(res)
		local item = items[0]
		t:eq(item.chartfile_set_id, 1)
		t:eq(item.chartfile_id, 1)
		t:eq(item.chartmeta_id, 0)
		t:eq(item.chartdiff_id, 0)
		t:eq(item.chartplay_id, 0)
	end

	t:eq(query("chartplays").count, 0, "plays mode requires chartplays")

	db:unload()
end

---@param t testing.T
function test.secondary_modes_combinations(t)
	local db, repo = setup()

	local function get_count(p_mode, s_mode, selection)
		repo.params.primary_mode = p_mode
		repo.params.secondary_mode = s_mode
		local res = repo:getViews(selection)
		return res.count
	end

	-- Rule: Filter by coarser, group by finer

	-- Selection: Set 1 (contains 2 files, 3 metas)
	local set1 = { chartfile_set_id = 1 }
	t:eq(get_count("chartfile_sets", "chartfile_sets", set1), 1, "P:sets, S:sets -> Just the set itself")
	t:eq(get_count("chartfile_sets", "chartfiles", set1), 2, "P:sets, S:files -> Files in set 1")
	t:eq(get_count("chartfile_sets", "chartmetas", set1), 3, "P:sets, S:metas -> Metas in set 1")

	-- Selection: Meta 1 (File 1, Set 1)
	local meta1 = { chartfile_set_id = 1, chartfile_id = 1, chartmeta_id = 1 }
	t:eq(get_count("chartmetas", "chartfile_sets", meta1), 3, "P:metas, S:sets -> Filtered by set 1 (coarser), grouped by metas (finer)")
	t:eq(get_count("chartmetas", "chartmetas", meta1), 1, "P:metas, S:metas -> Just the meta itself")
	
	-- Selection: Meta 4 (Set 2, contains 2 diffs, 3 plays)
	local meta4 = { chartfile_set_id = 2, chartfile_id = 3, chartmeta_id = 4 }
	t:eq(get_count("chartmetas", "chartdiffs", meta4), 2, "P:metas, S:diffs -> Diffs for meta 4")
	t:eq(get_count("chartmetas", "chartplays", meta4), 3, "P:metas, S:plays -> Plays for meta 4")

	-- Selection: Diff 1 (of Meta 4)
	local diff1 = { chartfile_set_id = 2, chartfile_id = 3, chartmeta_id = 4, chartdiff_id = 1 }
	t:eq(get_count("chartdiffs", "chartmetas", diff1), 2, "P:diffs, S:metas -> Filtered by meta 4 (coarser), grouped by diffs (finer)")

	db:unload()
end

---@param t testing.T
function test.aggregation_in_modes(t)
	local db, repo = setup()

	-- Test lamp aggregation in Meta mode
	-- We have 3 plays for Meta 4. Accuracy values are 0.90, 1.0, 0.98.
	repo.params.primary_mode = "chartmetas"
	repo.params.lamp = { accuracy__gte = 0.95 } -- Play 2 and 3 match (Meta 4)
	local res = repo:query()
	
	-- Should find ALL 4 Metas because lamp doesn't filter
	t:eq(res.count, 4)
	
	-- Only Meta 4 should have lamp = true
	local items, count = repo:unpackResult(res)
	local found_lamp = false
	for i = 0, count - 1 do
		local entry = items[i]
		if entry.chartmeta_id == 4 then
			t:eq(entry.lamp, true, "Meta 4 should have lamp")
			found_lamp = true
		else
			t:eq(entry.lamp, false, "Other metas should not have lamp")
		end
	end
	t:assert(found_lamp, "Should have found meta 4")

	db:unload()
end

return test
