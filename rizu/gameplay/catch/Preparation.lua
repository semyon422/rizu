local ModeNotes = require("chart.model.ModeNotes")
local Chartdiff = require("sea.chart.Chartdiff")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local ModifiersMetaState = require("sea.compute.ModifiersMetaState")

local Preparation = {}

---@param ctx sea.ComputeContext
---@param base sea.ReplayBase
function Preparation.compute(ctx, base)
	assert(base.rate >= 0.25 and base.rate <= 4, "Catch prototype: supported rates are 0.25x–4x.")
	assert(#base.modifiers == 0 and not base.tap_only and not base.columns_order, "Catch prototype: modifiers/reordering are unsupported.")
	local chart = assert(ctx.chart)
	local catch = ModeNotes.read(chart, "catch")
	local objects = catch.objects
	assert(#objects > 0, "Catch prototype: empty chart.")
	local bounds = Chartdiff()
	local chartmeta = assert(ctx.chartmeta)
	assert(chartmeta.mode == "catch", "Catch preparation requires native Catch metadata.")
	bounds.mode, bounds.rate, bounds.inputmode = chartmeta.mode, base.rate, "1fruits"
	bounds.start_time = objects[1].time
	bounds.duration = objects[#objects].time - bounds.start_time
	ctx.chartdiff = bounds
	ctx.state = ModifiersMetaState(chart.inputMode)
	ctx.diffcalc_context = DiffcalcContext(bounds, chart, base.rate)
	ctx.diffcalc_context.notes = {}
end

return Preparation
