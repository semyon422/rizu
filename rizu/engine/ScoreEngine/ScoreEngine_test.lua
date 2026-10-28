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

---@param t testing.T
function test.next_chart_keeps_hold_states_apart(t)
	local se = ScoreEngine()
	se:load({notes_count = 2})
	se:createByTimings(Timings("osuod", 8), Subtimings("scorev", 1), true)

	-- chart 1 ends with a hold still pressed
	se:receive({index = 1, column = 1, type = "hold", time = 1, delta_time = 0,
		old_state = "clear", new_state = "startPassedPressed"})

	se:nextChart({notes_count = 1})
	-- the first hold of chart 2 has the same index, missed at its head
	se:receive({index = 1, column = 1, type = "hold", time = 1, delta_time = 1,
		old_state = "clear", new_state = "startMissed"})
	se:receive({index = 1, column = 1, type = "hold", time = 2, delta_time = 1,
		old_state = "startMissed", new_state = "endMissed"})

	t:eq(se.events[2].index, 3)
	t:eq(se.judgesSource.judge_counter.judges[6], 1)
	t:assert(se.accuracySource.pressedLongNotes[1])
	t:eq(se.accuracySource.pressedLongNotes[3], nil)
end

---@param t testing.T
function test.late_system_loads_each_chart_of_course(t)
	local LunaticRaveScore = require("rizu.engine.ScoreEngine.scores.LunaticRaveScore")
	local Healths = require("sea.chart.Healths")

	---@param se rizu.ScoreEngine
	local function play(se)
		for chart = 1, 2 do
			se:nextChart({notes_count = chart == 1 and 1000 or 100} --[[@as sea.Chartdiff]], Healths("bmstotal", 300))
			se:receive({index = 1, column = 1, type = "tap", time = 1, delta_time = 1,
				old_state = "clear", new_state = "missed"})
		end
	end

	local early = ScoreEngine()
	early:loadCourse({notes_count = 1100, course = "class"})
	local early_hard = early:addScoreSystem(LunaticRaveScore(2, 2))
	play(early)

	local late = ScoreEngine()
	late:loadCourse({notes_count = 1100, course = "class"})
	play(late)
	local late_hard = late:addScoreSystem(LunaticRaveScore(2, 2))

	---@cast early_hard rizu.LunaticRaveScore
	---@cast late_hard rizu.LunaticRaveScore
	t:assert(math.abs(early_hard:getHealths() - (90 - 10 * (5 - 40 / 65))) < 1e-9)
	t:eq(late_hard:getHealths(), early_hard:getHealths())
	t:eq(late.sequence[2][late_hard:getKey()].healths, late_hard:getHealths())
end

---@param t testing.T
function test.gauge_is_picked_apart_from_the_timings(t)
	local Healths = require("sea.chart.Healths")
	local se = ScoreEngine()
	se:load({notes_count = 10} --[[@as sea.Chartdiff]])
	se:createByTimings(Timings("osuod", 8), Subtimings("scorev", 1), true, Healths("lr2", 2))

	t:eq(se.accuracySource:getKey(), "osu_mania_v1_od8")
	t:eq(se.healthsSource:getKey(), "lunatic_rank3_g2", "LR2 hard gauge with LR2's default rank")

	se:rescore(Timings("etternaj", 4))
	t:eq(se.accuracySource:getKey(), "etterna_accuracy_j4")
	t:eq(se.healthsSource:getKey(), "lunatic_rank3_g2", "rescoring keeps the play's gauge")

	local own = ScoreEngine()
	own:load({notes_count = 10} --[[@as sea.Chartdiff]])
	own:createByTimings(Timings("osuod", 8), nil, true, Healths("simple", 90))
	t:eq(own.healthsSource:getKey(), "osu_mania_v1_od8_hp90", "a picked HP is not the chart's")
	t:eq(own.accuracySource:getKey(), "osu_mania_v1_od8")
end

return test
