local ReplayCoder = require("sea.replays.ReplayCoder")
local ReplayLoader = require("sea.replays.ReplayLoader")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Timings = require("sea.chart.Timings")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

local function current_replay_base(version)
	local timings = Timings("sphere")
	return {
		version = version,
		timing_values = assert(TimingValuesFactory:get(timings)),
		created_at = 1,
		hash = string.rep("0", 32),
		index = 1,
		modifiers = {},
		rate = 1,
		mode = "mania",
		nearest = false,
		tap_only = false,
		timings = timings,
		subtimings = nil,
		healths = nil,
		columns_order = nil,
		custom = false,
		const = false,
		pause_count = 0,
		rate_type = "linear",
	}
end

---@param t testing.T
function test.load_pre_v1(t)
	local source = {
		events = {{1, 2, true}},
		hash = string.rep("0", 32),
		index = 1,
		modifiers = {
			{name = "NoLongNote", value = false},
			{id = 11, keys = 4, value = 4},
		},
	}
	local data = t:assert(ReplayCoder.encode(source))
	local replay = t:assert(ReplayLoader.load(data))

	t:eq(replay.version, 0)
	t:tdeq(replay.modifiers, {{id = 11, version = 0, value = 4}})
	t:tdeq(replay.frames, {
		{time = 1, event = VirtualInputEvent(2, true, 2)},
	})
end

---@param t testing.T
function test.load_v1(t)
	local source = current_replay_base(1)
	source.events = {{1, 2, true}}
	local data = t:assert(ReplayCoder.encode(source))
	local replay = t:assert(ReplayLoader.load(data))

	t:eq(replay.version, 1)
	t:tdeq(replay.frames, {
		{time = 1, event = VirtualInputEvent(2, true, 2)},
	})
end

---@param t testing.T
function test.load_v2(t)
	local source = current_replay_base(2)
	source.frames = {{time = 1, event = VirtualInputEvent(2, true, 2)}}
	local data = t:assert(ReplayCoder.encode(source))
	local replay = t:assert(ReplayLoader.load(data))

	t:eq(replay.version, 2)
	t:tdeq(replay.frames, source.frames)
end

return test
