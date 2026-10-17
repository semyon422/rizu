local TimingValues = require("sea.chart.TimingValues")

local test = {}

---@param t testing.T
function test.min_max_values(t)
	local tvs = TimingValues()
	tvs:setSimple(1, 2)

	t:eq(tvs:getMinTime("ShortNote"), -2)
	t:eq(tvs:getMaxTime("ShortNote"), 2)
end

return test
