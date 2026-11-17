local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ComputeState = require("sea.compute.ComputeState")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

local function create_db()
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	db.models.locations:create({id = 1, name = "test", path = "/test", is_relative = false, is_internal = false})
	db.models.chartfile_sets:create({id = 1, location_id = 1, name = "set", modified_at = 0, is_file = false})
	return db
end

-- Puts the database back to a version below 13, which still had the MinaCalc and user difficulty columns.
---@param db rizu.library.Database
---@param version integer
local function downgrade(db, version)
	for _, sql in ipairs({
		"DROP INDEX IF EXISTS chartdiffs_rizu_idx",
		"ALTER TABLE chartdiffs DROP COLUMN rizu_diff",
		"ALTER TABLE chartdiffs DROP COLUMN skillset",
		"ALTER TABLE chartdiffs DROP COLUMN pattern_1",
		"ALTER TABLE chartdiffs DROP COLUMN pattern_2",
		"ALTER TABLE chartdiffs DROP COLUMN pattern_share_1",
		"ALTER TABLE chartdiffs DROP COLUMN pattern_share_2",
		"ALTER TABLE chartdiffs DROP COLUMN pattern_bpm_1",
		"ALTER TABLE chartdiffs DROP COLUMN pattern_bpm_2",
		"ALTER TABLE chartdiffs ADD COLUMN msd_diff REAL",
		"ALTER TABLE chartdiffs ADD COLUMN msd_diff_data BLOB",
		"ALTER TABLE chartdiffs ADD COLUMN msd_diff_rates BLOB",
		"ALTER TABLE chartplays ADD COLUMN rating_msd REAL NOT NULL DEFAULT 0",
		"CREATE INDEX IF NOT EXISTS chartdiffs_msd_idx ON chartdiffs (msd_diff)",
		"ALTER TABLE chartdiffs ADD COLUMN user_diff REAL",
		"ALTER TABLE chartdiffs ADD COLUMN user_diff_data BLOB",
	}) do
		db.db:exec(sql)
	end
	db.db:user_version(version)
end

---@param db rizu.library.Database
---@param id integer
---@param state sea.ComputeState
local function create_play(db, id, state)
	local hash = string.format("%032d", id)
	db.models.chartplays:create(TestChartFactory():createChartplay({
		id = id, hash = hash, replay_hash = hash, compute_state = state, submitted_at = id * 10,
	}))
	db.models.chartfiles:create({id = id, set_id = 1, name = id .. ".osu", hash = hash, modified_at = 0})
end

---@param t testing.T
---@param db rizu.library.Database
---@param id integer
---@param state sea.ComputeState
local function check_play(t, db, id, state)
	local raw = db.db:query("SELECT compute_state, typeof(compute_state) AS storage_type FROM chartplays WHERE id = ?", {id})[1]
	t:eq(raw.storage_type, "integer")
	t:eq(tonumber(raw.compute_state), ComputeState:encode(state))
	t:eq(assert(db.models.chartplays:find({id = id})).compute_state, state)
end

---@param t testing.T
function test.enum_storage_and_derived_model_filters(t)
	local db = create_db()
	t:eq(db.db:user_version(), 13)
	for id, state in ipairs(ComputeState:list()) do
		create_play(db, id, state)
		check_play(t, db, id, state)
	end
	for _, name in ipairs({"chartplays", "chartplays_list", "chartplays_computable"}) do
		---@type sea.Chartplay[]
		local rows = db.models[name]:select({compute_state = "valid"})
		t:eq(#rows, 1)
		t:eq(rows[1].compute_state, "valid")
	end
	db.models.chartplays:update({compute_state = "valid"}, {id = 1})
	check_play(t, db, 1, "valid")
	db:unload()
end

---@param t testing.T
function test.version_9_mixed_states_migrate_without_losing_plays(t)
	local db = create_db()
	local states = {"new", "valid", "invalid", "new", "valid", "invalid"}
	for id, state in ipairs(states) do
		create_play(db, id, state)
		local raw_state = id <= 3 and state or ComputeState:encode(state)
		db.db:query("UPDATE chartplays SET compute_state = ? WHERE id = ?", {raw_state, id})
	end
	downgrade(db, 9)
	db:migrate()
	t:eq(db.db:user_version(), 13)
	for _, name in ipairs({"chartdiffs_enps_idx", "chartdiffs_osu_idx", "chartdiffs_rizu_idx", "chartplay_ratings_sort_idx"}) do
		t:eq(#db.db:query("SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?", {name}), 1, name)
	end
	for id, state in ipairs(states) do
		check_play(t, db, id, state)
		local play = assert(db.models.chartplays:find({id = id}))
		t:eq(play.replay_hash, string.format("%032d", id))
		t:eq(play.submitted_at, id * 10)
	end
	db:migrate()
	t:eq(db.models.chartplays:count(), 6)
	t:eq(db.models.chartfiles:count(), 6)
	downgrade(db, 9)
	db:migrate()
	for id, state in ipairs(states) do check_play(t, db, id, state) end
	db:unload()
end

---@param t testing.T
function test.version_12_drops_minacalc_and_adds_rizu_difficulty(t)
	local db = create_db()
	downgrade(db, 12)
	db:migrate()
	t:eq(db.db:user_version(), 13)
	for _, name in ipairs({"enps_diff", "osu_diff", "rizu_diff"}) do
		t:eq(#db.db:query("SELECT 1 FROM pragma_table_info('chartdiffs') WHERE name = ?", {name}), 1, name)
	end
	for _, name in ipairs({"msd_diff", "user_diff", "user_diff_data"}) do
		t:eq(#db.db:query("SELECT 1 FROM pragma_table_info('chartdiffs') WHERE name = ?", {name}), 0, name)
	end
	t:eq(#db.db:query("SELECT 1 FROM pragma_table_info('chartplays') WHERE name = 'rating_msd'"), 0)
	t:eq(#db.db:query("SELECT 1 FROM pragma_table_info('chartplay_ratings') WHERE name = 'calculator'"), 1)
	for _, name in ipairs({"skillset", "pattern_1", "pattern_2", "pattern_share_1", "pattern_share_2", "pattern_bpm_1", "pattern_bpm_2"}) do
		t:eq(#db.db:query("SELECT 1 FROM pragma_table_info('chartdiffs') WHERE name = ?", {name}), 1, name)
	end
	db:unload()
end

---@param t testing.T
function test.unknown_state_aborts_migration_without_advancing_version(t)
	for _, bad_state in ipairs({"unknown", 3}) do
		local db = create_db()
		create_play(db, 1, "valid")
		create_play(db, 2, "new")
		db.db:query("UPDATE chartplays SET compute_state = 'valid' WHERE id = 1")
		db.db:query("UPDATE chartplays SET compute_state = ? WHERE id = 2", {bad_state})
		downgrade(db, 9)
		t:has_error(db.migrate, db)
		t:eq(db.db:user_version(), 9)
		t:eq(db.db:query("SELECT compute_state FROM chartplays WHERE id = 1")[1].compute_state, "valid")
		db.db:query("UPDATE chartplays SET compute_state = 'new' WHERE id = 2")
		db:migrate()
		check_play(t, db, 1, "valid")
		check_play(t, db, 2, "new")
		db:unload()
	end
end

return test
