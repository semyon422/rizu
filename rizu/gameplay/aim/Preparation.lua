local Chartdiff = require("sea.chart.Chartdiff")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local ModifiersMetaState = require("sea.compute.ModifiersMetaState")
local AimChart = require("chart.format.osu.AimChart")

local Preparation = {}

---@param ctx sea.ComputeContext
---@param replay_base sea.ReplayBase
function Preparation.compute(ctx, replay_base)
	assert(replay_base.rate >= 0.25 and replay_base.rate <= 4,
		"Aim prototype supports playback rates from 0.25x to 4x only.")
	local chart = assert(ctx.chart)
	local aim = assert(chart.aim)
	local ok, err = AimChart.isSupported(aim)
	assert(ok, err)
	assert(#replay_base.modifiers == 0 and not replay_base.tap_only, "Aim prototype does not support chart modifiers.")
	assert(not replay_base.columns_order, "Aim prototype does not support column reordering.")
	-- Session bounds only: do not run mania difficulty or persist this as a chartdiff.
	local bounds = Chartdiff()
	bounds.mode = "osu"
	bounds.rate = replay_base.rate
	bounds.inputmode = "1osu"
	bounds.start_time = aim.objects[1].time
	bounds.duration = aim.objects[#aim.objects].time - bounds.start_time
	ctx.chartdiff = bounds
	ctx.state = ModifiersMetaState(chart.inputMode)
	ctx.diffcalc_context = DiffcalcContext(bounds, chart, replay_base.rate)
	ctx.diffcalc_context.notes = {}
end

return Preparation
