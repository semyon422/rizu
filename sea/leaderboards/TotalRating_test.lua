local TotalRating = require("sea.leaderboards.TotalRating")
local erfunc = require("chart.scoring.erfunc")

local test = {}

---@param t testing.T
function test.accuracy(t)
	local tr = TotalRating()

	tr:calc({})

	local accuracy = erfunc.erf(0.032 / (tr.accuracy * math.sqrt(2)))

	t:eq(accuracy, 0.5)
end

---@param t testing.T
function test.sums_each_rating_on_its_own(t)
	local tr = TotalRating()
	tr.avg_count = 2
	---@type table[]
	local plays = {
		{accuracy = 0.01, rating = 4, rating_msd = 30, rating_pp = 100, chartmeta_level = 10, difftable_level = 5},
		{accuracy = 0.01, rating = 2, rating_msd = 20, rating_pp = 100, chartmeta_level = 6, difftable_level = 3},
		{accuracy = 0.01, rating = 9, rating_msd = 90, rating_pp = 100, chartmeta_level = 90, difftable_level = 90},
	}
	tr:calc(plays --[[@as sea.Chartplayview[] ]])
	t:eq(tr.rating, 3)
	t:eq(tr.rating_msd, 25)
	t:eq(tr.chartmeta_level, 8)
	t:eq(tr.difftable_level, 4)
	t:eq(tr.rating_pp, 100 + 95 + 100 * 0.95 ^ 2, "pp weighs every play, not only the averaged ones")
end

return test
