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

return test
