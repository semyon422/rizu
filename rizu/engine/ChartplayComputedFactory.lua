local class = require("class")
local osu_pp = require("chart.scoring.osu_pp")
local minacalc = require("chart.scoring.minacalc")
local ChartplayComputed = require("sea.chart.ChartplayComputed")

---@class rizu.ChartplayComputedFactory
---@operator call: rizu.ChartplayComputedFactory
local ChartplayComputedFactory = class()

---@param chartdiff sea.Chartdiff
---@param diffcalc_context sphere.DiffcalcContext
---@param score_engine sphere.ScoreEngine
function ChartplayComputedFactory:new(chartdiff, diffcalc_context, score_engine)
	self.chartdiff = chartdiff
	self.diffcalc_context = diffcalc_context
	self.score_engine = score_engine
end

function ChartplayComputedFactory:getChartplayComputed(fast)
	local chartdiff = self.chartdiff
	local score_engine = self.score_engine

	local scores = score_engine.scores
	local judgesSource = assert(score_engine.judgesSource)

	local ns_score = scores.normalscore:getScore()

	local rating_msd = 0
	if not fast then
		local ctx = self.diffcalc_context
		local ssr = minacalc.calc_ssr(ctx:getSimplifiedNotes(), ctx.chart.inputMode:getColumns(), ctx.rate, ns_score)
		rating_msd = ssr.overall
	end

	local c = ChartplayComputed()
	c.pass = not scores.hp:isFailed()
	c.judges = judgesSource:getJudges()
	c.accuracy = scores.normalscore.accuracyAdjusted
	c.max_combo = scores.base.maxCombo
	c.miss_count = scores.base.missCount
	c.not_perfect_count = judgesSource:getNotPerfect()
	c.rating = ns_score * chartdiff.enps_diff
	c.rating_pp = osu_pp.calc_no_acc(ns_score, chartdiff.osu_diff, chartdiff.notes_count)
	c.rating_msd = rating_msd

	return c
end

return ChartplayComputedFactory
