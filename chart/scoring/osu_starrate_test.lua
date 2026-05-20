local osu_starrate = require("chart.scoring.osu_starrate")

local test = {}

function test.all(t)
	local notes = {}
	for time = 0, 10, 0.1 do
		table.insert(notes, {time = time, column = 1})
	end

	local bm = osu_starrate.Beatmap(notes, 1, 1)

	bm:calculateStarRate()

	t:assert(bm.starRate > 3)
end

return test
