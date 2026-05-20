local IDiffcalc = require("sphere.models.DifficultyModel.IDiffcalc")
local enps = require("chart.scoring.enps")

---@class sphere.EnpsDiffcalc: sphere.IDiffcalc
---@operator call: sphere.EnpsDiffcalc
local EnpsDiffcalc = IDiffcalc + {}

EnpsDiffcalc.name = "enps"
EnpsDiffcalc.chartdiff_field = "enps_diff"

---@param ctx sphere.DiffcalcContext
function EnpsDiffcalc:compute(ctx)
	local notes = ctx:getSimplifiedNotes()
	ctx.chartdiff.enps_diff = enps.getEnps(notes) * ctx.rate
end

return EnpsDiffcalc
