local CalculatorTask = require("rizu.library.tasks.CalculatorTask")
local FakeTaskContext = require("rizu.library.tasks.FakeTaskContext")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ChartviewsRepo = require("rizu.library.repos.ChartviewsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")
local FunctionTimer = require("time.FunctionTimer")

local test = {}

local timer = FunctionTimer(function() return 0 end)

---@param t testing.T
function test.rates_missing_charts_and_queries_them(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local models = db.models
	local factory = TestChartFactory()

	models.locations:create({id = 1, name = "Test", path = "/test", is_relative = 0, is_internal = 0})
	models.chartfile_sets:create({id = 1, location_id = 1, name = "Set", dir = "s", modified_at = 0, is_file = 0})
	for id, mode in ipairs({"mania", "mania", "taiko", "mania"}) do
		local hash = "h" .. id
		models.chartfiles:create({id = id, set_id = 1, name = hash .. ".osu", hash = hash, modified_at = 0})
		models.chartmetas:create(factory:createChartmeta({id = id, hash = hash, mode = mode}))
	end

	local context = FakeTaskContext()
	local chart = factory:create("4key", {{time = 0, column = 1}, {time = 1, column = 2}}).chart
	for i = 1, 3 do
		context.charts["h" .. i] = {chart}
	end

	local calls = 0
	---@type rizu.library.Calculator
	local calc = {name = "test", version = 1, keys = {"stream"}, compute = function(_, ctx, chartmeta)
		calls = calls + 1
		t:eq(ctx.rate, 1)
		-- Chart 2 isn't rated.
		return chartmeta.id == 1 and {[0] = 12.345, stream = 3} or nil
	end}

	local task = CalculatorTask({calc}, models, ChartsRepo(models, {"enps_diff"}), context, timer, function(hash)
		return context:getChartsByHash(hash)
	end)

	local function values()
		local out = {} ---@type {[string]: integer|string}
		for _, row in ipairs(models.chart_difficulties:select()) do
			out[row.chart_id .. ":" .. row.key] = row.value or "null"
		end
		return out
	end

	task:computeMissing()
	t:eq(calls, 2, "the taiko chart is skipped, the one without a file fails before computing")
	t:tdeq(values(), {["1:0"] = 1235, ["1:1"] = 300, ["2:0"] = "null", ["4:0"] = "null"})

	task:computeMissing()
	t:eq(calls, 2, "stored values, also NULL ones, are not computed again")

	calc.version = 2
	task:computeMissing()
	t:eq(calls, 4, "a new version computes every value again")

	local repo = ChartviewsRepo(models)
	repo:setSync(true)
	repo.params = {difficulty = "calc:test", where = {difficulty__gte = 12}}
	t:eq(repo:query().count, 1)
	repo.params.where = {difficulty__lt = 12}
	t:eq(repo:query().count, 0, "unrated charts match no difficulty filter")

	models.chartmetas:delete({id = 1})
	t:tdeq(values(), {["2:0"] = "null", ["4:0"] = "null"}, "values go with their chart")

	db:unload()
end

return test
