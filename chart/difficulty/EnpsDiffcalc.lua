local IDiffcalc = require("chart.difficulty.IDiffcalc")
local enps = require("chart.scoring.enps")

---@class chart.EnpsDiffcalc: chart.IDiffcalc
---@operator call: chart.EnpsDiffcalc
local EnpsDiffcalc = IDiffcalc + {}

EnpsDiffcalc.name = "enps"
EnpsDiffcalc.chartdiff_field = "enps_diff"

---@param ctx chart.DiffcalcContext
function EnpsDiffcalc:compute(ctx)
	local notes = ctx:getSimplifiedNotes()
	ctx.chartdiff.enps_diff = enps.getEnps(notes) * ctx.rate
end

return EnpsDiffcalc
