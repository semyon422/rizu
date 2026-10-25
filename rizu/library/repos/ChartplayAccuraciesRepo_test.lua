local LinuxFilesystem = require("fs.LinuxFilesystem")
local Database = require("rizu.library.Database")
local ChartplayAccuraciesRepo = require("rizu.library.repos.ChartplayAccuraciesRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local Timings = require("sea.chart.Timings")

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
function test.score_list_reads_the_auto_accuracy(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local repo = ChartplayAccuraciesRepo(db.models)
	local charts_repo = ChartsRepo(db.models)
	local tcf = TestChartFactory()
	db.models.chartmetas:create(tcf:createChartmeta({hash = "osu", timings = Timings("osuod", 8)}))
	db.models.chartmetas:create(tcf:createChartmeta({hash = "sm", timings = Timings("etternaj", 4)}))
	db.models.chartplays:create(tcf:createChartplay({id = 1, hash = "osu", replay_hash = "1"}))
	db.models.chartplays:create(tcf:createChartplay({id = 2, hash = "sm", replay_hash = "2"}))

	-- Auto timings of an osu! chart are score V1, so the V2 and OD 9 rows are not it.
	repo:setAccuracies(1, {
		{timings = 2180, subtimings = 1102, accuracy = 0.9},
		{timings = 2190, subtimings = 1101, accuracy = 0.8},
		{timings = 2180, subtimings = 1101, accuracy = 0.95},
	})
	---@type {auto_accuracy: number?, auto_timings: integer?}
	local play = charts_repo:getChartplaysForChartmeta({hash = "osu", index = 1})[1]
	t:eq(play.auto_accuracy, 0.95)
	t:eq(play.auto_timings, 2180)

	-- Nothing stored for the chart's own timings: the score list shows "-".
	repo:setAccuracies(2, {{timings = 2305, subtimings = 0, accuracy = 0.9}})
	---@type {auto_accuracy: number?}
	local sm_play = charts_repo:getChartplaysForChartmeta({hash = "sm", index = 1})[1]
	t:eq(sm_play.auto_accuracy, nil)
	db:unload()
end

return test
