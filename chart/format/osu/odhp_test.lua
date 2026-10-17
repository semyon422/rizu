local odhp = require("chart.format.osu.odhp")

local test = {}

---@param t testing.T
function test.od_round(t)
	local prec = 1000
	for i = 0, 1 * prec do
		local od = i / prec
		t:eq(odhp.od3(od), odhp.od3(odhp.round_od(od, 10)))
		t:eq(odhp.od3(od), odhp.od3(odhp.round_od(od, 4)))
		t:eq(odhp.od3(od), odhp.od3(odhp.round_od(od, 3)))
	end

	t:eq(odhp.round_od(0.33, 10), 0.3)
	t:eq(odhp.round_od(0.34, 10), 0.4)
	t:eq(odhp.round_od(0.66, 10), 0.6)
	t:eq(odhp.round_od(0.67, 10), 0.7)
	t:eq(odhp.round_od(0.99, 10), 0.9)
	t:eq(odhp.round_od(1.00, 10), 1.0)
	t:eq(odhp.round_od(1.01, 10), 1.0)

	t:has_error(odhp.round_od, 0, 2)
end

return test
