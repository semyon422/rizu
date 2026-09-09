local Chartdiff = require("sea.chart.Chartdiff")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local ModifiersMetaState = require("sea.compute.ModifiersMetaState")
local Rules = require("rizu.gameplay.sdvx.Rules")

local Preparation = {}

---@param ctx sea.ComputeContext
---@param base sea.ReplayBase
function Preparation.compute(ctx, base)
	assert(base.rate >= 0.25 and base.rate <= 4, "SDVX prototype: supported rates are 0.25x–4x.")
	assert(#base.modifiers == 0 and not base.tap_only and not base.columns_order, "SDVX prototype: modifiers/reordering are unsupported.")
	local chart = assert(ctx.chart)
	local sdvx = assert(chart.sdvx)
	Rules(sdvx) -- Validate bounded simulation before entering gameplay.
	local bounds = Chartdiff()
	bounds.mode, bounds.rate, bounds.inputmode = "sdvx", base.rate, tostring(chart.inputMode)
	local start, ending = math.huge, -math.huge
	for _, object in ipairs(sdvx.buttons) do
		start, ending = math.min(start, object.time), math.max(ending, object.end_time)
	end
	for _, chain in ipairs(sdvx.lasers) do
		start = math.min(start, chain.segments[1].time)
		ending = math.max(ending, chain.segments[#chain.segments].end_time)
	end
	bounds.start_time, bounds.duration = start, ending - start
	ctx.chartdiff = bounds
	ctx.state = ModifiersMetaState(chart.inputMode)
	ctx.diffcalc_context = DiffcalcContext(bounds, chart, base.rate)
	ctx.diffcalc_context.notes = {}
end

return Preparation
