local TimingPoints = require("chart.format.osu.sections.TimingPoints")

local test = {}

function test.basic(t)
	local timing_points = TimingPoints()

	local lines = {
		"46163,3,4,2,0,20,1,0",
		"46179,0.001,4,2,0,20,1,1",
		"46180,300,4,2,0,20,1,8",
		"49780,-1000,4,2,0,20,0,9",
		"110400,0.001,4,2,0,20,1,0",
		"110401,-1e-50,4,2,0,20,1,0",
		"",  -- because osu
	}

	timing_points:decode(lines)
	t:eq(#timing_points, #lines - 1)
	t:tdeq(timing_points:encode(), lines)
end

return test
