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

return test
