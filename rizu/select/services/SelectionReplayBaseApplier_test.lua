local Healths = require("sea.chart.Healths")
local ReplayBase = require("sea.replays.ReplayBase")
local SelectionReplayBaseApplier = require("rizu.select.services.SelectionReplayBaseApplier")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")

local test = {}

local function createConfigModel(secondary_mode)
	return {
		configs = {
			settings = {
				select = {
					secondary_mode = secondary_mode,
				},
			},
		},
	}
end

local function createChartview()
	return {
		modifiers = {{id = 1, value = 2}},
		rate = 1.5,
		mode = "mania",
		nearest = true,
		tap_only = true,
		timings = Timings("osuod", 8),
		subtimings = Subtimings("scorev", 1),
		healths = Healths("simple", 10),
		columns_order = {4, 3, 2, 1},
		custom = true,
		const = true,
		rate_type = "exp",
	}
end

---@param t testing.T
function test.coarse_modes_do_not_update_replay_base(t)
	for _, mode in ipairs({"chartfile_sets", "chartfiles", "chartmetas"}) do
		local replayBase = ReplayBase()
		replayBase.rate = 0.75

		SelectionReplayBaseApplier(createConfigModel(mode), replayBase):apply(createChartview())

		t:eq(replayBase.rate, 0.75, mode)
		t:tdeq(replayBase.modifiers, {}, mode)
		t:eq(replayBase.nearest, false, mode)
	end
end

---@param t testing.T
function test.chartdiff_mode_updates_only_diff_key_fields(t)
	local replayBase = ReplayBase()

	SelectionReplayBaseApplier(createConfigModel("chartdiffs"), replayBase):apply(createChartview())

	t:tdeq(replayBase.modifiers, {{id = 1, value = 2}})
	t:eq(replayBase.rate, 1.5)
	t:eq(replayBase.mode, "mania")

	t:eq(replayBase.nearest, false)
	t:eq(replayBase.tap_only, false)
	t:eq(replayBase.timings, Timings("sphere"))
	t:eq(replayBase.subtimings, nil)
	t:eq(replayBase.healths, nil)
	t:eq(replayBase.columns_order, nil)
	t:eq(replayBase.custom, false)
	t:eq(replayBase.const, false)
	t:eq(replayBase.rate_type, "linear")
end

---@param t testing.T
function test.chartplays_mode_updates_chartplay_base_fields(t)
	local replayBase = ReplayBase()

	SelectionReplayBaseApplier(createConfigModel("chartplays"), replayBase):apply(createChartview())

	t:tdeq(replayBase.modifiers, {{id = 1, value = 2}})
	t:eq(replayBase.rate, 1.5)
	t:eq(replayBase.mode, "mania")
	t:eq(replayBase.nearest, true)
	t:eq(replayBase.tap_only, true)
	t:eq(replayBase.timings, Timings("osuod", 8))
	t:eq(replayBase.subtimings, Subtimings("scorev", 1))
	t:eq(replayBase.healths, Healths("simple", 10))
	t:tdeq(replayBase.columns_order, {4, 3, 2, 1})
	t:eq(replayBase.custom, true)
	t:eq(replayBase.const, true)
	t:eq(replayBase.rate_type, "exp")
end

---@param t testing.T
function test.build_selection_replay_base_does_not_mutate_current_replay_base(t)
	local replayBase = ReplayBase()
	replayBase.rate = 0.75
	replayBase.modifiers = {{id = 9, value = 1}}

	local selectionReplayBase, applied = SelectionReplayBaseApplier(
		createConfigModel("chartdiffs"),
		replayBase
	):buildSelectionReplayBase(createChartview())

	t:eq(applied, true)
	t:eq(replayBase.rate, 0.75)
	t:tdeq(replayBase.modifiers, {{id = 9, value = 1}})
	t:eq(selectionReplayBase.rate, 1.5)
	t:tdeq(selectionReplayBase.modifiers, {{id = 1, value = 2}})
end

---@param t testing.T
function test.build_selection_replay_base_preserves_manual_fields_outside_selection_scope(t)
	local replayBase = ReplayBase()
	replayBase.nearest = true
	replayBase.columns_order = {1, 2, 3, 4}

	local selectionReplayBase = SelectionReplayBaseApplier(
		createConfigModel("chartdiffs"),
		replayBase
	):buildSelectionReplayBase(createChartview())

	t:eq(selectionReplayBase.nearest, true)
	t:tdeq(selectionReplayBase.columns_order, {1, 2, 3, 4})
end

return test
