local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ChartviewsRepo = require("rizu.library.repos.ChartviewsRepo")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")
local test = {}

---@param t testing.T
function test.client_and_server_backfill_leave_ambiguous_osu_unknown(t)
	local fs = LinuxFilesystem()
	for _, path in ipairs({"rizu/library/sql/migrate8.sql", "sea/storage/server/migrations/11.sql"}) do
		local db = LjsqliteDatabase()
		db:open(":memory:")
		db:exec([[CREATE TABLE chartmetas (id INTEGER PRIMARY KEY, format INTEGER, inputmode TEXT);
		INSERT INTO chartmetas VALUES (1,1,'2key'),(2,1,'1osu'),(3,1,'1fruits'),(4,1,'1taiko'),(5,7,'4bt2fx2laserleft2laserright'),(6,0,'2key'),(7,1,'4key');]])
		db:exec(assert(fs:read(path)))
		local expected = {[2] = 2, [3] = 3, [4] = 1, [5] = 4, [6] = 0, [7] = 0}
		for _, row in db:iter("SELECT id, mode FROM chartmetas ORDER BY id") do t:eq(tonumber(row.mode), expected[tonumber(row.id)]) end
		db:close()
	end
end

---@param t testing.T
function test.native_mode_survives_chartview_independently_of_diff_mode(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local factory = TestChartFactory()
	db.models.locations:create({id = 1, name = "test", path = "/test", is_relative = false, is_internal = false})
	db.models.chartfile_sets:create({id = 1, location_id = 1, name = "set", modified_at = 0, is_file = false})
	db.models.chartfiles:create({id = 1, set_id = 1, name = "test.osu", hash = "test", modified_at = 0})
	db.models.chartmetas:create(factory:createChartmeta({hash = "test", mode = "taiko", format = "osu", inputmode = "2key"}))
	db.models.chartdiffs:create(factory:createChartdiff({hash = "test", mode = "mania", rate = 1}))
	local repo = ChartviewsRepo(db.models)
	repo.params = {primary_mode = "chartmetas", secondary_mode = "chartmetas", difficulty = "enps_diff", where = {}}
	local view = assert(repo:getChartview({chartmeta_id = 1}))
	t:eq(view.chartmeta_mode, "taiko")
	t:eq(view.mode, "mania")
	t:eq(#ChartfilesRepo(db.models):selectUnhashedChartfiles(nil, 1), 0)
	db.db:exec("UPDATE chartmetas SET mode = NULL")
	t:eq(#ChartfilesRepo(db.models):selectUnhashedChartfiles(nil, 1), 1)
	db:unload()
end

return test
