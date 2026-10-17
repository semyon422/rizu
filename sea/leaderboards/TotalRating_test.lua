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

return test
