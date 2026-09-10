local ModeNotes = require("chart.model.ModeNotes")
local Chartdiff = require("sea.chart.Chartdiff")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local ModifiersMetaState = require("sea.compute.ModifiersMetaState")

local Preparation = {}

---@param ctx sea.ComputeContext
---@param base sea.ReplayBase
function Preparation.compute(ctx, base)
	assert(base.rate >= 0.25 and base.rate <= 4, "Taiko prototype: supported rates are 0.25x–4x.")
	assert(#base.modifiers == 0 and not base.tap_only and not base.columns_order, "Taiko prototype: modifiers/reordering are unsupported.")
	local chart = assert(ctx.chart)
	local objects = ModeNotes.read(chart, "taiko").objects
	local bounds = Chartdiff()
	bounds.mode, bounds.rate, bounds.inputmode = "taiko", base.rate, "1taiko"
	bounds.start_time = objects[1].time
	local ending = bounds.start_time
	for _, object in ipairs(objects) do ending = math.max(ending, object.end_time) end
	bounds.duration = ending - bounds.start_time
	ctx.chartdiff = bounds
	ctx.state = ModifiersMetaState(chart.inputMode)
	ctx.diffcalc_context = DiffcalcContext(bounds, chart, base.rate)
	ctx.diffcalc_context.notes = {}
end

return Preparation
