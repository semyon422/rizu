local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local Chartplays = require("sea.chart.Chartplays")
local UserInsecure = require("sea.access.UserInsecure")

local test = {}

---@param t testing.T
function test.repair_notes_preview_preserves_other_fields_and_checks_source(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartsRepo(db.models)
	local factory = TestChartFactory()
	local old = "old\0preview"
	local repaired = "new\0preview"
	local row = repo:createChartdiff(factory:createChartdiff({
		id = 1, hash = "hash", index = 1, notes_preview = old, enps_diff = 12,
	}))
	local sibling = repo:createChartdiff(factory:createChartdiff({
		id = 2, hash = "hash", index = 2, notes_preview = old,
	}))

	repo:repairNotesPreview(1, "stale", repaired)
	t:tdeq(repo:getChartdiff(1), row)
	repo:repairNotesPreview(1, old, repaired)
	row.notes_preview = repaired
	t:tdeq(repo:getChartdiff(1), row)
	t:tdeq(repo:getChartdiff(2), sibling)
	repo:repairNotesPreview(1, old, "late")
	t:tdeq(repo:getChartdiff(1), row)
	t:has_error(function()
		repo:repairNotesPreview(1, repaired, "")
	end)
	db:unload()
end

---@param t testing.T
function test.chartdiff_difficulties_are_stored_in_hundredths(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartsRepo(db.models, {"enps_diff", "osu_diff"})
	local chartdiff = TestChartFactory():createChartdiff({id = 1, hash = "hash", enps_diff = 12.3456, osu_diff = 5})
	local created = repo:createUpdateChartdiff(chartdiff, 10)
	t:eq(created.enps_diff, 12.35)
	t:eq(repo:getChartdiff(1).enps_diff, 12.35)
	t:eq(repo:getChartdiff(1).osu_diff, 5)
	t:eq(#repo:getIncompleteChartdiffs(), 0)

	local same = TestChartFactory():createChartdiff({id = 1, hash = "hash", enps_diff = 12.3456, osu_diff = 5})
	t:eq(repo:createUpdateChartdiff(same, 20).computed_at, 10, "an unchanged chartdiff is not updated")

	repo:resetDiffcalcField("enps_diff")
	local incomplete = repo:getIncompleteChartdiffs()
	t:eq(#incomplete, 1)
	t:eq(incomplete[1].enps_diff, nil)
	t:eq(incomplete[1].osu_diff, 5)
	db:unload()
end

---@param t testing.T
function test.best_chartplays_by_rating_take_one_passed_play_per_chart(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartsRepo(db.models)
	local factory = TestChartFactory()
	---@param hash string
	---@param pp number
	---@param rating number
	---@param pass boolean
	local function add(hash, pp, rating, pass)
		local chartplay = factory:createChartplay({hash = hash, rating_pp = pp, rating = rating})
		chartplay.pass = pass
		repo:createChartplay(chartplay)
	end
	add("a", 100, 20, true)
	add("a", 300, 10, true)
	add("a", 900, 90, false)
	add("b", 200, 30, true)

	local by_pp = repo:getBestChartplaysByRating(1, "rating_pp", 100)
	t:eq(#by_pp, 2)
	t:eq(by_pp[1].rating_pp, 300, "a failed play does not count")
	t:eq(by_pp[2].rating_pp, 200)

	local by_rating = repo:getBestChartplaysByRating(1, "rating", 100)
	t:eq(by_rating[1].rating, 30)
	t:eq(by_rating[2].rating, 20, "each rating takes its own best play of a chart")
	t:eq(#repo:getBestChartplaysByRating(1, "rating_pp", 1), 1)
	t:eq(#repo:getBestChartplaysByRating(2, "rating_pp", 100), 0)
end

---@param t testing.T
function test.recent_chartplays_all_are_valid_newest_first_with_names_and_titles(t)
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()
	local repo = ChartsRepo(db.models)
	local factory = TestChartFactory()
	local user = UserInsecure()
	user.name, user.email, user.password, user.latest_activity, user.created_at = "Aqua", "a@b", "", 0, 0
	db.models.users:create(user)
	local chartmeta = factory:createChartmeta({hash = "a", title = "Song A"})
	chartmeta.name = "4K Hard"
	repo:createChartmeta(chartmeta)
	---@param id integer
	---@param hash string
	---@param state sea.ComputeState
	local function add(id, hash, state)
		repo:createChartplay(factory:createChartplay({
			id = id, user_id = 1, hash = hash, replay_hash = tostring(id), compute_state = state,
		}))
	end
	add(1, "a", "valid")
	add(2, "a", "invalid")
	add(3, "unknown", "valid")
	add(4, "a", "valid")

	local recent = repo:getRecentChartplaysAll(10)
	t:eq(#recent, 3, "an invalid play is left out")
	t:eq(recent[1].chartplay.id, 4)
	t:eq(recent[2].chartplay.id, 3)
	t:eq(recent[3].chartplay.id, 1)
	t:eq(recent[1].user_name, "Aqua")
	t:eq(recent[1].chartmeta.title, "Song A")
	t:eq(recent[2].chartmeta, nil, "a chart the server does not know")
	t:eq(#repo:getRecentChartplaysAll(1), 1)

	local scores = Chartplays.getRecentScores({charts_repo = repo} --[[@as sea.Chartplays]], 10)
	t:eq(scores[1].user_name, "Aqua")
	t:eq(scores[1].title, "Song A")
	t:eq(scores[1].chart_name, "4K Hard")
	t:eq(scores[2].title, "?")
	t:eq(type(scores[1].accuracy), "number")
	db:close()
end

return test
