local Healths = require("sea.chart.Healths")
local ReplayBaseConfigurator = require("rizu.gameplay.ReplayBaseConfigurator")
local SelectionReplayBaseApplier = require("rizu.select.services.SelectionReplayBaseApplier")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")

local test = {}

local function createSettings(secondary_mode)
	local settings = Settings.createConfig(FakeFilesystem())
	settings:setChoice(Settings.keys.select.secondary_mode, secondary_mode)
	return settings
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

---@param settings rizu.config.Config
---@return rizu.select.services.SelectionReplayBaseApplier
---@return rizu.gameplay.ReplayBaseConfigurator
local function createApplier(settings)
	local configurator = ReplayBaseConfigurator(settings)
	return SelectionReplayBaseApplier(settings, configurator), configurator
end

---@param t testing.T
function test.coarse_modes_do_not_update_configurator(t)
	for _, mode in ipairs({"chartfile_sets", "chartfiles", "chartmetas"}) do
		local applier, configurator = createApplier(createSettings(mode))
		configurator.rate = 0.75

		applier:apply(createChartview())

		t:eq(configurator.rate, 0.75, mode)
		t:tdeq(configurator.modifiers, {}, mode)
		t:eq(configurator.tap_only, false, mode)
	end
end

---@param t testing.T
function test.chartdiff_mode_updates_only_diff_key_fields(t)
	local applier, configurator = createApplier(createSettings("chartdiffs"))

	applier:apply(createChartview())

	t:tdeq(configurator.modifiers, {{id = 1, value = 2}})
	t:eq(configurator.rate, 1.5)
	t:eq(configurator.tap_only, false)
	t:eq(configurator.columns_order, nil)
	t:eq(configurator.custom, false)
	t:eq(configurator.const, false)
	t:eq(configurator.rate_type, "linear")
end

---@param t testing.T
function test.chartplays_mode_updates_play_config_fields(t)
	local settings = createSettings("chartplays")
	local applier, configurator = createApplier(settings)

	applier:apply(createChartview())

	t:tdeq(configurator.modifiers, {{id = 1, value = 2}})
	t:eq(configurator.rate, 1.5)
	t:eq(configurator.tap_only, true)
	t:tdeq(configurator.columns_order, {4, 3, 2, 1})
	t:eq(configurator.custom, true)
	t:eq(configurator.const, true)
	t:eq(configurator.rate_type, "exp")
	-- The score's timings and gauge stay out of the play config.
	t:eq(configurator:createReplayBase().timings, Timings("sphere"))
	t:eq(settings:getBoolean(Settings.keys.replay_base.auto_timings), true)
end

---@param t testing.T
function test.build_selection_replay_base_does_not_mutate_configurator(t)
	local applier, configurator = createApplier(createSettings("chartdiffs"))
	configurator.rate = 0.75
	configurator.modifiers = {{id = 9, value = 1}}

	local selectionReplayBase, applied = applier:buildSelectionReplayBase(createChartview())

	t:eq(applied, true)
	t:eq(configurator.rate, 0.75)
	t:tdeq(configurator.modifiers, {{id = 9, value = 1}})
	t:eq(selectionReplayBase.rate, 1.5)
	t:tdeq(selectionReplayBase.modifiers, {{id = 1, value = 2}})
end

---@param t testing.T
function test.build_selection_replay_base_preserves_manual_fields_outside_selection_scope(t)
	local applier, configurator = createApplier(createSettings("chartdiffs"))
	configurator.const = true
	configurator.columns_order = {1, 2, 3, 4}

	local selectionReplayBase = applier:buildSelectionReplayBase(createChartview())

	t:eq(selectionReplayBase.const, true)
	t:tdeq(selectionReplayBase.columns_order, {1, 2, 3, 4})
end

return test
