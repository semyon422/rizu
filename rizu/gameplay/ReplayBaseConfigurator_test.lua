local ReplayBaseConfigurator = require("rizu.gameplay.ReplayBaseConfigurator")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
local Chartmeta = require("sea.chart.Chartmeta")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")

local test = {}

---@return rizu.gameplay.ReplayBaseConfigurator
---@return rizu.config.Config
local function newConfigurator()
	local settings = Settings.createConfig(FakeFilesystem())
	return ReplayBaseConfigurator(settings), settings
end

---@param t testing.T
function test.chart_timings_are_not_repeated(t)
	local configurator = newConfigurator()
	local chartmeta = Chartmeta()
	chartmeta.timings = Timings("osuod", 10)

	local replayBase = configurator:createReplayBase()
	replayBase.nearest = true
	configurator:applyChart(replayBase, chartmeta)

	t:eq(replayBase.timings, nil)
	t:eq(replayBase.subtimings, Subtimings("scorev", 1))
	t:eq(replayBase.nearest, false)
end

---@param t testing.T
function test.iidx_format_uses_iidx_timings(t)
	local configurator = newConfigurator()
	local chartmeta = Chartmeta()
	chartmeta.format = "iidx"

	local replayBase = configurator:createReplayBase()
	configurator:applyChart(replayBase, chartmeta)

	t:eq(replayBase.timings, Timings("iidx"))
	t:eq(replayBase.subtimings, nil)
	local timing_values = replayBase.timing_values
	t:eq(timing_values.ShortNote.hit[1], -0.25)
	t:eq(timing_values.ShortNote.hit[2], 0.25)
	t:eq(timing_values.LongNoteEnd.hit[2], 0.25)
end

---@param t testing.T
function test.stepmania_is_etterna_j4_with_nearest(t)
	local configurator = newConfigurator()
	local chartmeta = Chartmeta()
	chartmeta.format = "stepmania"

	local replayBase = configurator:createReplayBase()
	configurator:applyChart(replayBase, chartmeta)

	t:eq(replayBase.timings, Timings("etternaj", 4))
	t:eq(replayBase.subtimings, nil)
	t:eq(replayBase.nearest, true)
end

---@param t testing.T
function test.picked_timings_replace_auto(t)
	local configurator, settings = newConfigurator()
	t:eq(ReplayBaseConfigurator.getPickedTimings(settings), nil)
	settings:setBoolean(Settings.keys.replay_base.auto_timings, false)
	settings:setNumber(Settings.keys.timings.osuod, 8.999999)
	settings:setNumber(Settings.keys.timings.osu_score_version, 2)

	local chartmeta = Chartmeta()
	chartmeta.format = "stepmania"
	local replayBase = configurator:createReplayBase()
	configurator:applyChart(replayBase, chartmeta)

	t:eq(replayBase.timings, Timings("osuod", 9))
	t:eq(replayBase.subtimings, Subtimings("scorev", 2))
	t:eq(replayBase.nearest, true)

	settings:setChoice(Settings.keys.timings.system, "quaver")
	t:eq(assert(ReplayBaseConfigurator.getPickedTimings(settings)).timings, Timings("quaver"))
end

---@param t testing.T
function test.picked_healths_do_not_follow_the_timings(t)
	local configurator, settings = newConfigurator()
	local chartmeta = Chartmeta()
	chartmeta.format = "osu"

	local replayBase = configurator:createReplayBase()
	configurator:applyChart(replayBase, chartmeta)
	t:eq(replayBase.healths, nil)

	settings:setBoolean(Settings.keys.replay_base.auto_healths, false)
	settings:setChoice(Settings.keys.healths.system, "iidx")
	settings:setNumber(Settings.keys.healths.iidx_gauge, 4)
	configurator:applyChart(replayBase, chartmeta)
	t:eq(replayBase.timings, Timings("osuod", 8))
	t:eq(replayBase.healths, Healths("iidx", 4))

	settings:setChoice(Settings.keys.healths.system, "simple")
	settings:setNumber(Settings.keys.healths.osu_hp, 7.699999)
	t:eq(ReplayBaseConfigurator.getPickedHealths(settings), Healths("simple", 77))

	t:eq(Healths.decode(Healths("iidx", 4):encode()), Healths("iidx", 4))
end

---@param t testing.T
function test.accuracy_follows_the_timings_unless_picked(t)
	local _, settings = newConfigurator()
	local keys = Settings.keys

	t:eq(ReplayBaseConfigurator.getPickedAccuracy(settings), nil)
	t:eq(ReplayBaseConfigurator.getAccuracyScoring(settings, nil, "stepmania").timings, Timings("etternaj", 4))

	settings:setBoolean(keys.replay_base.auto_timings, false)
	t:eq(ReplayBaseConfigurator.getAccuracyScoring(settings, nil, "stepmania").timings, Timings("osuod", 8))

	settings:setBoolean(keys.replay_base.auto_accuracy, false)
	settings:setChoice(keys.accuracy.system, "etternaj")
	settings:setNumber(keys.accuracy.etternaj, 6)
	t:eq(ReplayBaseConfigurator.getAccuracyScoring(settings, nil, "stepmania").timings, Timings("etternaj", 6))
end

---@param t testing.T
function test.each_play_gets_its_own_replay_base(t)
	local configurator, settings = newConfigurator()
	configurator.rate = 1.5
	table.insert(configurator.modifiers, {id = 1, version = 0})

	local a = configurator:createReplayBase("4key")
	a.modifiers[1].value = 3
	a.timings = Timings("quaver")
	t:eq(configurator.modifiers[1].value, nil)
	t:eq(configurator:createReplayBase("4key").rate, 1.5)
	t:eq(a.columns_order, nil)

	settings:setBoolean(Settings.keys.replay_base.random_columns, true)
	local shuffled = false
	for _ = 1, 20 do
		shuffled = shuffled or configurator:createReplayBase("4key").columns_order ~= nil
	end
	t:assert(shuffled)
	t:eq(configurator.columns_order, nil)
	t:eq(configurator:createReplayBase().columns_order, nil)
end

return test
