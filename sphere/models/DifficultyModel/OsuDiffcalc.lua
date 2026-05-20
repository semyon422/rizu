local IDiffcalc = require("sphere.models.DifficultyModel.IDiffcalc")
local osu_starrate = require("chart.scoring.osu_starrate")

---@class sphere.OsuDiffcalc: sphere.IDiffcalc
---@operator call: sphere.OsuDiffcalc
local OsuDiffcalc = IDiffcalc + {}

OsuDiffcalc.name = "osu!mania"
OsuDiffcalc.chartdiff_field = "osu_diff"

---@param ctx sphere.DiffcalcContext
function OsuDiffcalc:compute(ctx)
	local notes = ctx:getSimplifiedNotes()

	local columns = ctx.chart.inputMode:getColumns()
	local bm = osu_starrate.Beatmap(notes, columns, ctx.rate)

	ctx.chartdiff.osu_diff = bm:calculateStarRate()
end

return OsuDiffcalc
