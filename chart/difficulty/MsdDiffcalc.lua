local IDiffcalc = require("chart.difficulty.IDiffcalc")
local minacalc = require("chart.scoring.minacalc")

---@class chart.MsdDiffcalc: chart.IDiffcalc
---@operator call: chart.MsdDiffcalc
local MsdDiffcalc = IDiffcalc + {}

MsdDiffcalc.name = "MSD"
MsdDiffcalc.chartdiff_field = "msd_diff"

---@param ctx chart.DiffcalcContext
function MsdDiffcalc:compute(ctx)
	local notes = ctx:getSimplifiedNotes()

	local columns = ctx.chart.inputMode:getColumns()
	local ssr = minacalc.calc(notes, columns, ctx.rate)
	local rate_multipliers = minacalc.calc_rate_multipliers(notes, columns, ssr)
	ctx.chartdiff.msd_diff = ssr.overall
	ctx.chartdiff.msd_diff_data = ssr
	ctx.chartdiff.msd_diff_rates = rate_multipliers
end

return MsdDiffcalc
