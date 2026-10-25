local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ChartplayAccuraciesRepo = require("rizu.library.repos.ChartplayAccuraciesRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

---@param t testing.T
function test.set_replaces_and_deleting_the_play_removes_them(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartplayAccuraciesRepo(db.models)
	db.models.chartplays:create(TestChartFactory():createChartplay({id = 1}))

	repo:setAccuracies(1, {
		{timings = 2190, subtimings = 1101, accuracy = 0.98},
		{timings = 2304, subtimings = 0, accuracy = 0.95},
	})
	t:eq(#repo:getAccuracies(1), 2)

	repo:setAccuracies(1, {{timings = 2304, subtimings = 0, accuracy = 0.9}})
	local rows = repo:getAccuracies(1)
	t:eq(#rows, 1)
	t:eq(rows[1].accuracy, 0.9)

	db.models.chartplays:delete({id = 1})
	t:eq(#repo:getAccuracies(1), 0)
	db:unload()
end

---@param t testing.T
function test.hits_round_trip_until_the_version_changes(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartplayAccuraciesRepo(db.models)
	db.models.chartplays:create(TestChartFactory():createChartplay({id = 1}))
	t:eq(repo:getHits(1), nil)

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

	-- Hits of another engine version are made again.
	db.models.chartplay_hits:update({version = ChartplayAccuraciesRepo.hits_version - 1}, {chartplay_id = 1})
	t:eq(repo:getHits(1), nil)

	db.models.chartplays:delete({id = 1})
	t:eq(db.models.chartplay_hits:count(), 0)
	db:unload()
end

return test
