local ChartplayComputedFactory = require("rizu.engine.ChartplayComputedFactory")
local ScoreEngine = require("rizu.engine.ScoreEngine")
local Timings = require("sea.chart.Timings")
local osu_pp = require("chart.scoring.osu_pp")

local test = {}

---@param chart_timings sea.Timings?
---@return sea.ChartplayComputed
---@return rizu.ScoreEngine
local function compute(chart_timings)
	local chartdiff = {notes_count = 2, judges_count = 2, enps_diff = 10, osu_diff = 3} --[[@as sea.Chartdiff]]
	local se = ScoreEngine()
	se:load(chartdiff)
	-- Judged with Etterna windows: the PP still counts osu!mania accuracy.
	se:createByTimings(Timings("etternaj", 4), nil, true)
	se:receive({index = 1, column = 1, type = "tap", time = 1, delta_time = 0, old_state = "clear", new_state = "passed"})
	se:receive({index = 2, column = 1, type = "tap", time = 2, delta_time = 0.045, old_state = "clear", new_state = "passed"})
	return ChartplayComputedFactory(chartdiff, nil, se, chart_timings):getChartplayComputed(true), se
end

---@param t testing.T
function test.pp_counts_osu_accuracy_with_the_chart_od(t)
	local c, se = compute(nil)
	local osu = assert(se:getScoreSystem("osu_mania_v1_od8")) --[[@as rizu.OsuManiaV1Score]]
	t:assert(osu:getAccuracy() < 1)
	t:eq(c.rating_pp, osu_pp.calc(osu:getAccuracy(), 3, 2, 8))
	t:eq(c.rating, se.scores.soundsphere:getScore() * 10, "ENPS stays normalscore")
	t:eq((se.accuracySource --[[@as rizu.ScoreSystem]]):getKey(), "etterna_accuracy_j4", "the play's sources are not changed")

	local od5, se5 = compute(Timings("osuod", 5))
	local osu5 = assert(se5:getScoreSystem("osu_mania_v1_od5")) --[[@as rizu.OsuManiaV1Score]]
	t:assert(osu5:getAccuracy() > osu:getAccuracy(), "45 ms is a 300 at OD5, not at OD8")
	t:eq(od5.rating_pp, osu_pp.calc(osu5:getAccuracy(), 3, 2, 5))
end

return test
