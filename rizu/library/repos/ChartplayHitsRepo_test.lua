local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ChartplayHitsRepo = require("rizu.library.repos.ChartplayHitsRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

---@param t testing.T
function test.hits_round_trip_until_the_version_changes(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartplayHitsRepo(db.models)
	db.models.chartplays:create(TestChartFactory():createChartplay({id = 1}))
	t:eq(repo:getHits(1), nil)
	t:tdeq(repo:getStoredIds(), {})

	---@type rizu.LogicNoteChange[]
	local events = {
		{index = 1, column = "key1", type = "tap", time = 1.5, delta_time = -0.012,
			old_state = "clear", new_state = "passed"},
		{index = 2, column = "key2", type = "hold", time = 2, delta_time = 0.03, press_delta_time = 0.01,
			old_state = "startPassedPressed", new_state = "endPassed"},
	}
	repo:setHits(1, {notes_count = 2, inputmode = "4key"}, events)
	repo:setHits(1, {notes_count = 2, inputmode = "4key"}, events)
	t:tdeq(repo:getHits(1), {notes_count = 2, inputmode = "4key", events = events})
	t:tdeq(repo:getStoredIds(), {[1] = true})

	-- Hits of another engine version are made again.
	db.models.chartplay_hits:update({version = ChartplayHitsRepo.hits_version - 1}, {chartplay_id = 1})
	t:eq(repo:getHits(1), nil)
	t:tdeq(repo:getStoredIds(), {})

	db.models.chartplays:delete({id = 1})
	t:eq(db.models.chartplay_hits:count(), 0)
	db:unload()
end

return test
