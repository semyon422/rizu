local IDiffcalc = require("chart.difficulty.IDiffcalc")
local RefChart = require("chart.refchart.RefChart")
local Restorer = require("chart.refchart.Restorer")
local ChartEncoder = require("chart.format.sph.ChartEncoder")
local SphPreview = require("chart.format.sph.SphPreview")
local LinesCleaner = require("chart.format.sph.lines.LinesCleaner")
local IntervalLayer = require("chart.model.layers.IntervalLayer")

---@class chart.PreviewDiffcalc: chart.IDiffcalc
---@operator call: chart.PreviewDiffcalc
local PreviewDiffcalc = IDiffcalc + {}

PreviewDiffcalc.name = "preview"
PreviewDiffcalc.chartdiff_field = "notes_preview"

---@param ctx chart.DiffcalcContext
function PreviewDiffcalc:compute(ctx)
	-- make a copy because code below mutates chart
	local refchart = RefChart(ctx.chart)
	local chart = Restorer():restore(refchart)

	local ok, err = pcall(function()
		chart.layers.main:toInterval()
		assert(IntervalLayer * chart.layers.main)

		local encoder = ChartEncoder()
		local sph = encoder:encodeSph(chart)

		local preview_ver = 1
		if chart.inputMode:getColumns() > 10 then
			preview_ver = 0
		end

		-- SphPreview still have some issues with encoding unusual charts
		local lines = sph.sphLines:encode()
		lines = LinesCleaner:clean(lines)
		ctx.chartdiff.notes_preview = SphPreview:encodeLines(lines, preview_ver)
	end)

	if not ok then
		ctx.chartdiff.notes_preview = ""
		print(err)
	end
end

return PreviewDiffcalc
