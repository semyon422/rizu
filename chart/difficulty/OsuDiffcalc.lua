local IDiffcalc = require("chart.difficulty.IDiffcalc")
local osu_starrate = require("chart.scoring.osu_starrate")

---@class chart.OsuDiffcalc: chart.IDiffcalc
---@operator call: chart.OsuDiffcalc
local OsuDiffcalc = IDiffcalc + {}

OsuDiffcalc.name = "osu!mania"
OsuDiffcalc.chartdiff_field = "osu_diff"

---@param ctx chart.DiffcalcContext
function OsuDiffcalc:compute(ctx)
	local notes = ctx:getSimplifiedNotes()

	local columns = ctx.chart.inputMode:getColumns()
	local bm = osu_starrate.Beatmap(notes, columns, ctx.rate)

	ctx.chartdiff.osu_diff = bm:calculateStarRate()
end

return OsuDiffcalc
