local ModeNotes = require("chart.model.ModeNotes")
local SliderSamples = require("chart.format.osu.SliderSamples")
local Tracking = require("rizu.gameplay.aim.Tracking")
local Stacking = require("rizu.gameplay.aim.Stacking")
local Sliders = require("rizu.gameplay.aim.Sliders")
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
	local aim = ModeNotes.read(chart, "osu")
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
	local end_time = aim.objects[#aim.objects].time
	for _, object in ipairs(aim.objects) do
		if object.kind == "spinner" then end_time = math.max(end_time, assert(object.end_time)) end
	end
	local prepared, sliders = pcall(Sliders.prepare, aim)
	assert(prepared, "Aim prototype: invalid slider geometry/timing: " .. tostring(sliders))
	SliderSamples.prepare(aim, sliders, chart.resources)
	Tracking.validateBudget(sliders)
	for _, slider in pairs(sliders) do
		end_time = math.max(end_time, slider.timing.end_time)
	end
	if aim.stack_leniency ~= nil then
		local ar = aim.approach_rate
		local preempt = ar < 5 and 1.8 - 0.12 * ar or 1.2 - 0.15 * (ar - 5)
		Stacking.apply(aim, sliders, preempt, 54.4 - 4.48 * aim.circle_size)
	end
	bounds.duration = end_time - bounds.start_time
	ctx.chartdiff = bounds
	ctx.state = ModifiersMetaState(chart.inputMode)
	ctx.diffcalc_context = DiffcalcContext(bounds, chart, replay_base.rate)
	ctx.diffcalc_context.notes = {}
end

return Preparation
