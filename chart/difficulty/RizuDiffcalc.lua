local IDiffcalc = require("chart.difficulty.IDiffcalc")
local RizuDifficulty = require("rizu.library.RizuDifficulty")

---@class chart.RizuDiffcalc: chart.IDiffcalc
---@operator call: chart.RizuDiffcalc
local RizuDiffcalc = IDiffcalc + {}

RizuDiffcalc.name = "rizu"
RizuDiffcalc.chartdiff_field = "rizu_diff"

---@param ctx chart.DiffcalcContext
function RizuDiffcalc:compute(ctx)
	ctx.chartdiff.rizu_diff = RizuDifficulty.rate(ctx:getSimplifiedNotes(), tostring(ctx.chart.inputMode))
end

return RizuDiffcalc
