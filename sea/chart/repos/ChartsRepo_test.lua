local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")

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
function test.best_chartplays_by_rating_take_one_passed_play_per_chart(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartsRepo(db.models)
	local factory = TestChartFactory()
	---@param hash string
	---@param pp number
	---@param msd number
	---@param pass boolean
	local function add(hash, pp, msd, pass)
		local chartplay = factory:createChartplay({hash = hash, rating_pp = pp, rating_msd = msd})
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

	local by_msd = repo:getBestChartplaysByRating(1, "rating_msd", 100)
	t:eq(by_msd[1].rating_msd, 30)
	t:eq(by_msd[2].rating_msd, 20, "each rating takes its own best play of a chart")
	t:eq(#repo:getBestChartplaysByRating(1, "rating_pp", 1), 1)
	t:eq(#repo:getBestChartplaysByRating(2, "rating_pp", 100), 0)
end

return test
