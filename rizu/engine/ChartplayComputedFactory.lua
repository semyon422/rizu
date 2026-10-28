local class = require("class")
local osu_pp = require("chart.scoring.osu_pp")
local minacalc = require("chart.scoring.minacalc")
local ChartplayComputed = require("sea.chart.ChartplayComputed")
local OsuManiaV1Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV1Score")
local EtternaAccuracy = require("rizu.engine.ScoreEngine.scores.EtternaAccuracy")

---@class rizu.ChartplayComputedFactory
---@operator call: rizu.ChartplayComputedFactory
local ChartplayComputedFactory = class()

---@param chartdiff sea.Chartdiff
---@param diffcalc_context chart.DiffcalcContext
---@param score_engine rizu.ScoreEngine
---@param chart_timings sea.Timings? The chart's own, whose OD the osu! PP takes.
function ChartplayComputedFactory:new(chartdiff, diffcalc_context, score_engine, chart_timings)
	self.chartdiff = chartdiff
	self.diffcalc_context = diffcalc_context
	self.score_engine = score_engine
	self.chart_timings = chart_timings
end

function ChartplayComputedFactory:getChartplayComputed(fast)
	local chartdiff = self.chartdiff
	local score_engine = self.score_engine

	local scores = score_engine.scores
	local judgesSource = assert(score_engine.judgesSource)

	local ns_score = scores.soundsphere:getScore()

	-- Each rating has its own system, whatever the play was judged with: scored here from the play's events.
	local timings = self.chart_timings
	local od = timings and timings.name == "osuod" and timings.data or 8
	local osu = score_engine:addScoreSystem(OsuManiaV1Score(od)) --[[@as rizu.OsuManiaV1Score]]

	local rating_msd = 0
	if not fast then
		local etterna = score_engine:addScoreSystem(EtternaAccuracy(4)) --[[@as rizu.EtternaAccuracy]]
		local ctx = self.diffcalc_context
		local ssr = minacalc.calc_ssr(ctx:getSimplifiedNotes(), ctx.chart.inputMode:getColumns(), ctx.rate,
			etterna:getAccuracy())
		rating_msd = ssr.overall
	end

	local c = ChartplayComputed()
	c.pass = assert(score_engine.healthsSource):isPassed()
	c.judges = judgesSource:getJudges()
	c.accuracy = scores.soundsphere.accuracyAdjusted
	c.max_combo = scores.base.maxCombo
	c.miss_count = scores.base.missCount
	c.not_perfect_count = judgesSource:getNotPerfect()
	c.rating = ns_score * chartdiff.enps_diff
	c.rating_pp = osu_pp.calc(osu:getAccuracy(), chartdiff.osu_diff, chartdiff.notes_count, od)
	c.rating_msd = rating_msd

	return c
end

return ChartplayComputedFactory
