local CalculatorsRepo = require("rizu.library.repos.CalculatorsRepo")
local Database = require("rizu.library.Database")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

---@param t testing.T
function test.rates_plays(t)
	local db = Database(LinuxFilesystem())
	db:load(":memory:")
	local models = db.models
	local factory = TestChartFactory()
	for id = 1, 3 do
		models.chartplays:create(factory:createChartplay({id = id, hash = "h", index = 1}))
	end

	local ctx, engine = {}, {}
	---@type rizu.library.Calculator[]
	local calcs = {
		{name = "ssr", version = 1, keys = {"stream", "ln"}, computePlay = function(_, c, e, id)
			t:assert(c == ctx and e == engine and id == 1)
			return {[0] = 25.004, ln = 30}
		end},
		{name = "broken", version = 1, keys = {"stream"}, computePlay = function() return {[0] = 1, jack = 2} end},
		{name = "charts_only", version = 1, compute = function() return 1 end},
	}
	local repo = CalculatorsRepo(models)

	local function values()
		local out = {} ---@type {[string]: integer|string}
		for _, row in ipairs(models.chartplay_ratings:select()) do
			local calc = assert(models.calculators:find({id = row.calc_id}))
			out[row.chartplay_id .. calc.name .. row.key] = row.value or "null"
		end
		return out
	end

	t:eq(#repo:getChartplaysMissingRatings(calcs), 3)

	local errors = repo:ratePlay(calcs, 1, ctx, engine)
	t:eq(#errors, 1)
	t:assert(errors[1]:find("^broken: .*unknown key: jack"))
	repo:ratePlay(calcs, 2)
	t:tdeq(values(), {["1ssr0"] = 2500, ["1ssr2"] = 3000, ["1broken0"] = "null", ["2ssr0"] = "null", ["2broken0"] = "null"},
		"named values go to their keys; a failed or unplayable play is stored as not rated; a chart calculator rates no plays")
	t:tdeq(repo:getChartplaysMissingRatings(calcs), {3})

	calcs[1].version = 2
	t:tdeq(repo:getChartplaysMissingRatings(calcs), {1, 2, 3}, "a new version rates every play again")
	t:tdeq(values(), {["1broken0"] = "null", ["2broken0"] = "null"})

	models.chartplays:delete({id = 1})
	t:tdeq(values(), {["2broken0"] = "null"}, "ratings go with their play")

	db:unload()
end

return test
