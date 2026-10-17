local HitObjects = require("chart.format.osu.sections.HitObjects")

local test = {}

-- need more tests for std sliders

function test.basic(t)
	local hit_objects = HitObjects()

	local lines = {
		"448,192,1000,5,0,0:0:0:0:",
		"320,192,1000,1,0,1:2:3:4:sound.wav",
		"64,192,1000,1,4,0:0:0:0:",
		"360,192,nan,128,0,nan:0:0:0:0:",
		"320,192,1000,128,0,2000:0:0:0:0:",
		"448,192,1000,1,0,0:0:0:0:",
		"304,80,2065,6,0,L|384:80,3,80,0|0|0|0,0:0|0:0|0:0|0:0,0:0:0:0:",
		"256,192,402119,12,0,405119,0:0:0:0:",
	}

	hit_objects:decode(lines)

	t:eq(#hit_objects, #lines)
	t:tdeq(hit_objects:encode(), lines)
end

return test
