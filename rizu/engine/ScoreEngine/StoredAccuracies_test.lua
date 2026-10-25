local ScoreEngine = require("rizu.engine.ScoreEngine")
local StoredAccuracies = require("rizu.engine.ScoreEngine.StoredAccuracies")
local Timings = require("sea.chart.Timings")

local test = {}

---@param t testing.T
function test.parse_keeps_valid_tokens_once(t)
	t:tdeq(StoredAccuracies.parse("auto, osuod:9:1,etternaj:4,auto,osuod:8.55,sphere,nope,quaver"), {
		"auto", "osuod:9:1", "etternaj:4", "quaver",
	})
	t:tdeq(StoredAccuracies.parse(""), {})
end

---@param t testing.T
function test.compute_scores_each_system_once(t)
	local se = ScoreEngine()
	se:load({notes_count = 1})
	se:receive({
		index = 1,
		column = 1,
		type = "tap",
		time = 1,
		delta_time = 0,
		old_state = "clear",
		new_state = "passed",
	})

	-- "auto" on an osu! chart is V1 at the chart's OD, so it is the same row as "osuod:8".
	local rows = StoredAccuracies.compute(se, {"auto", "osuod:8", "osuod:9:2", "etternaj:4"}, Timings("osuod", 8))
	t:eq(#rows, 3)
	t:tdeq(rows[1], {timings = 2180, subtimings = 1101, accuracy = 1})
	t:eq(rows[2].timings, 2190)
	t:eq(rows[2].subtimings, 1102)
	t:eq(rows[3].timings, 2304)
	t:eq(rows[3].subtimings, 0)

	t:tdeq(StoredAccuracies.compute(se, {"auto"}, Timings("sphere")), {})
end

---@param t testing.T
function test.format_uses_the_system_format(t)
	t:eq(StoredAccuracies.format(Timings("osuod", 8), nil, 0.98765), "98.77%")
	t:eq(StoredAccuracies.format(Timings("etternaj", 4), nil, 0.5), "50.00%")
	t:eq(StoredAccuracies.format(Timings("sphere"), nil, 0.5), nil)
end

return test
