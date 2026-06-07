local Replay = require("sea.replays.Replay")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local OsuReplayConverter = require("sea.replays.OsuReplayConverter")
local ColumnsOrder = require("sea.chart.ColumnsOrder")
local Mods = require("bancho.constants.Mods")
local bit = require("bit")

local test = {}

---@param t testing.T
function test.roundtrip_osr_mania(t)
	local converter = OsuReplayConverter()
	local replay = Replay()
	replay.version = 2
	replay.hash = "0123456789abcdef0123456789abcdef"
	replay.index = 1
	replay.modifiers = {}
	replay.rate = 1.5
	replay.mode = "mania"
	replay.nearest = true
	replay.tap_only = false
	replay.timings = Timings("osuod", 8)
	replay.subtimings = Subtimings("scorev", 2)
	replay.timing_values = assert(TimingValuesFactory:get(replay.timings, replay.subtimings))
	replay.healths = nil
	replay.columns_order = ColumnsOrder("4key"):mirror():export()
	replay.custom = false
	replay.const = false
	replay.pause_count = 0
	replay.created_at = 123456
	replay.rate_type = "exp"
	replay.frames = {
		{time = 0.000, event = {id = 1, column = 1, value = true}},
		{time = 0.100, event = {id = 1, column = 1, value = false}},
		{time = 0.200, event = {id = 2, column = 2, value = true}},
		{time = 0.300, event = {id = 2, column = 2, value = false}},
	}

	local osr_data = converter:toOsr({artist = "A", title = "T", name = "D", inputmode = "4key"}, replay, "Player", {
		judges = {5, 4, 3, 2, 1, 0},
		max_combo = 123,
		perfect = false,
	}, 42)
	local loaded, _, replay_hash = assert(converter:fromOsr(osr_data, replay.hash, replay.index, 8, "4key"))

	t:eq(loaded.hash, replay.hash)
	t:eq(loaded.index, replay.index)
	t:eq(loaded.rate, 1.5)
	t:eq(loaded.subtimings, Subtimings("scorev", 2))
	t:tdeq(loaded.columns_order, ColumnsOrder("4key"):mirror():export())
	t:eq(#loaded.modifiers, 0)
	t:eq(#loaded.frames, #replay.frames)
	t:eq(replay_hash:match("^[0-9a-f]+$") ~= nil, true)
end

---@param t testing.T
function test.random_mod_is_rejected_on_import(t)
	local converter = OsuReplayConverter()
	local replay = Replay()
	replay.version = 2
	replay.hash = "0123456789abcdef0123456789abcdef"
	replay.index = 1
	replay.modifiers = {}
	replay.rate = 1
	replay.mode = "mania"
	replay.nearest = true
	replay.tap_only = false
	replay.timings = Timings("osuod", 8)
	replay.subtimings = Subtimings("scorev", 1)
	replay.timing_values = assert(TimingValuesFactory:get(replay.timings, replay.subtimings))
	replay.healths = nil
	replay.columns_order = {2, 1, 3, 4}
	replay.custom = false
	replay.const = false
	replay.pause_count = 0
	replay.created_at = 123456
	replay.rate_type = "linear"
	replay.frames = {
		{time = 0.000, event = {id = 1, column = 1, value = true}},
		{time = 0.100, event = {id = 1, column = 1, value = false}},
	}

	local osr_data = converter:toOsr({artist = "A", title = "T", name = "D", inputmode = "4key"}, replay, "Player", {
		judges = {1, 0, 0, 0, 0, 0},
		max_combo = 1,
		perfect = true,
	}, 42)
	local loaded, err = converter:fromOsr(osr_data, replay.hash, replay.index, 8, "4key")

	t:eq(loaded, nil)
	t:eq(err, "random mod is not supported")
	t:eq(bit.band(converter:getModsFromReplay(replay, "4key"), Mods.RANDOM) ~= 0, true)
end

return test
