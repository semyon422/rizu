local ScoreEngine = require("rizu.engine.ScoreEngine")
local Scoring = require("rizu.engine.scoring.Scoring")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

local test = {}

---@param t testing.T
function test.qwe(t)
	local se = ScoreEngine()
	se.judgement = "soundsphere"

	se:load({notes_count = 0})

	local systems = assert(Scoring(Timings("osuod", 8.5), Subtimings("scorev", 2)):createScoreSystems())
	local osu_od85_v2 = systems[1]

	se:addScoreSystem(osu_od85_v2)
	se:select(osu_od85_v2:getKey())

	t:eq(se.accuracySource, osu_od85_v2)
	t:eq(se.judgesSource, osu_od85_v2)

	t:eq(se.accuracySource:getAccuracyString(), "0.00%")

	se:receive({
		index = 1,
		column = 2,
		type = "tap",
		time = 1,
		delta_time = 0,
		old_state = "clear",
		new_state = "passed",
	})
	local slice = se.sequence[1][osu_od85_v2:getKey()]
	t:eq(slice.input, 2)
	t:eq(slice.judge_index, 1)
end

---@param t testing.T
function test.rescore_fills_sequence(t)
	local se = ScoreEngine()
	se:load({notes_count = 1})

	se:receive({
		index = 1,
		column = 2,
		type = "tap",
		time = 1,
		delta_time = 0,
		old_state = "clear",
		new_state = "passed",
	})

	t:assert(se:rescore(Timings("osuod", 8.5), Subtimings("scorev", 2)))
	t:eq(se.accuracySource:getKey(), "osu_mania_v2_od8.5")
	t:eq(se.sequence[1][se.judgesSource:getKey()].judge_index, 1)

	local ok, err = se:rescore(Timings("simple"))
	t:assert(not ok and err)
	t:eq(se.accuracySource:getKey(), "osu_mania_v2_od8.5")
end

---@param t testing.T
function test.default_judges_slice_has_misses(t)
	local se = ScoreEngine()
	se:load({notes_count = 1} --[[@as sea.Chartdiff]])
	se:receive({
		index = 1,
		column = 2,
		type = "tap",
		time = 1,
		delta_time = 1,
		old_state = "clear",
		new_state = "missed",
	})
	local slice = se.sequence[1][se.judgesSource:getKey()]
	t:eq(slice.input, 2)
	t:eq(slice.judge_index, -1)
end

return test
