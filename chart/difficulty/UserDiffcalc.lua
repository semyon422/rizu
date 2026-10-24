local IDiffcalc = require("chart.difficulty.IDiffcalc")
local rizucalc = require("chart.scoring.rizucalc")

---@class chart.UserDiffcalc: chart.IDiffcalc
---@operator call: chart.UserDiffcalc
local UserDiffcalc = IDiffcalc + {}

UserDiffcalc.name = "user"
UserDiffcalc.chartdiff_field = "user_diff"

---@param ctx chart.DiffcalcContext
function UserDiffcalc:compute(ctx)
	local notes = ctx:getSimplifiedNotes()
	-- shortcut: rizucalc takes over user_diff, move it to its own field once players can set user_diff themselves
	ctx.chartdiff.user_diff = rizucalc.calc(notes, tostring(ctx.chart.inputMode), ctx.rate) or 0
	ctx.chartdiff.user_diff_data = ""
end

return UserDiffcalc
