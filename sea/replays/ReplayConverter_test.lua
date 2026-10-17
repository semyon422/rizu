local valid = require("valid")
local Healths = require("sea.chart.Healths")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")
local Replay = require("sea.replays.Replay")
local ReplayConverter = require("sea.replays.ReplayConverter")
local Subtimings = require("sea.chart.Subtimings")
local TimingValues = require("sea.chart.TimingValues")
local Timings = require("sea.chart.Timings")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

local function timing_object(hit, miss)
	return {
		hit = {-hit, hit},
		miss = {-miss, miss},
	}
end

---@param t testing.T
function test.convert_events(t)
	local frames = ReplayConverter:convertEvents({
		{1.25, 3, true},
		{2.5, 4, false},
	})

	t:tdeq(frames, {
		{time = 1.25, event = VirtualInputEvent(3, true, 3)},
		{time = 2.5, event = VirtualInputEvent(4, false, 4)},
	})
end

---@param t testing.T
function test.convert_timing_generations(t)
	local short_score = timing_object(0.1, 0.2)
	local old_score_timings = {
		ShortScoreNote = short_score,
		LongScoreNote = {
			startHit = {-0.11, 0.11},
			startMiss = {-0.21, 0.21},
			endHit = {-0.12, 0.12},
			endMiss = {-0.22, 0.22},
		},
	}
	ReplayConverter:convertTimings({timings = old_score_timings})
	t:eq(old_score_timings.ShortNote, short_score)
	t:tdeq(old_score_timings.LongNoteStart, {
		hit = {-0.11, 0.11},
		miss = {-0.21, 0.21},
	})
	t:tdeq(old_score_timings.LongNoteEnd, {
		hit = {-0.12, 0.12},
		miss = {-0.22, 0.22},
	})
	t:eq(old_score_timings.ShortScoreNote, nil)
	t:eq(old_score_timings.LongScoreNote, nil)

	local intermediate_timings = {
		ShortNote = timing_object(0.1, 0.2),
		LongNote = {
			startHit = {-0.13, 0.13},
			startMiss = {-0.23, 0.23},
			endHit = {-0.14, 0.14},
			endMiss = {-0.24, 0.24},
		},
	}
	ReplayConverter:convertTimings({timings = intermediate_timings})
	t:tdeq(intermediate_timings.LongNoteStart, {
		hit = {-0.13, 0.13},
		miss = {-0.23, 0.23},
	})
	t:tdeq(intermediate_timings.LongNoteEnd, {
		hit = {-0.14, 0.14},
		miss = {-0.24, 0.24},
	})
	t:eq(intermediate_timings.LongNote, nil)

	local missing_timings = {}
	ReplayConverter:convertTimings(missing_timings)
	t:eq(missing_timings.timings, ReplayConverter.oldTimings)
end

---@param t testing.T
function test.convert_legacy_modifiers(t)
	local replay = {
		rate = 1,
		const = false,
		modifiers = {
			{name = "TimeRateQ", value = 1},
			{name = "TimeRateX", value = 1.25},
			{name = "ConstSpeed", value = true},
			{name = "SpeedMode", value = "constant"},
			{name = "NoLongNote", value = false},
			{name = "NoLongNote", value = true},
			{name = "Automap", keys = 6},
			{name = "MultiplePlay", value = 1},
			{name = "MultiOverPlay", value = 1},
			{name = "Alternate", value = 1},
			{id = ModifierRegistry.enum.Automap, keys = 10, value = 10},
			{id = 99901, version = 0, value = 5, custom_key = "removed"},
			{name = "DeletedModifier", value = 1},
		},
	}

	ReplayConverter:convertModifiers(replay)

	t:eq(replay.rate, 1.25 * 2 ^ 0.1)
	t:eq(replay.const, true)
	t:tdeq(replay.modifiers, {
		{id = ModifierRegistry.enum.NoLongNote, version = 0},
		{id = ModifierRegistry.enum.Automap, version = -1, value = 6},
		{id = ModifierRegistry.enum.MultiplePlay, version = 0, value = 2},
		{id = ModifierRegistry.enum.MultiOverPlay, version = 0, value = 2},
		{id = ModifierRegistry.enum.Alternate, version = 0, value = "key"},
		{id = ModifierRegistry.enum.Automap, version = 0, value = 10},
		{id = 99901, version = 0, value = 5},
	})
end

---@param t testing.T
function test.convert_versioned_replays(t)
	local timings = Timings("sphere")
	local subtimings = Subtimings("scorev", 1)
	local healths = Healths("simple", 20)
	local timing_values = TimingValues():setSimple(0.1, 0.2)
	local version_one = {
		version = 1,
		events = {{1, 2, true}},
		timings = timings,
		subtimings = subtimings,
		healths = healths,
		timing_values = timing_values,
	}

	local converted_one = ReplayConverter:convert(version_one)
	t:eq(getmetatable(converted_one), Replay)
	t:eq(getmetatable(converted_one.timings), Timings)
	t:eq(getmetatable(converted_one.subtimings), Subtimings)
	t:eq(getmetatable(converted_one.healths), Healths)
	t:eq(getmetatable(converted_one.timing_values), TimingValues)
	t:eq(converted_one.events, nil)
	t:tdeq(converted_one.frames, {
		{time = 1, event = VirtualInputEvent(2, true, 2)},
	})

	local frames = {{time = 1, event = VirtualInputEvent(2, true, 2)}}
	local converted_two = ReplayConverter:convert({version = 2, frames = frames})
	t:eq(getmetatable(converted_two), Replay)
	t:eq(converted_two.frames, frames)

	t:eq(t:has_error(ReplayConverter.convert, ReplayConverter, {version = 3}), "invalid replay version")
end

---@param t testing.T
function test.convert_minimal_pre_v1_replay(t)
	local replay = ReplayConverter:convert({
		events = {{1, 2, true}},
		hash = string.rep("0", 32),
		index = 1,
		modifiers = {},
	})

	t:eq(replay.version, 0)
	t:eq(replay.rate, 1)
	t:eq(replay.mode, "mania")
	t:eq(replay.nearest, false)
	t:eq(replay.tap_only, false)
	t:eq(replay.custom, false)
	t:eq(replay.const, false)
	t:eq(replay.pause_count, 0)
	t:eq(replay.created_at, 0)
	t:eq(replay.rate_type, "exp")
	t:eq(getmetatable(replay), Replay)
	t:assert(valid.format(replay:validate()))
end

---@param t testing.T
function test.convert_pre_v1_metadata(t)
	local timing_values = {
		ShortNote = timing_object(0.1, 0.2),
		LongNoteStart = timing_object(0.1, 0.2),
		LongNoteEnd = timing_object(0.1, 0.2),
		nearest = true,
	}
	local replay = ReplayConverter:convert({
		frames = {},
		hash = string.rep("0", 32),
		index = 1,
		rate = 1.23456,
		const = true,
		single = true,
		time = 42,
		timings = timing_values,
	})

	t:eq(replay.rate, 1.235)
	t:eq(replay.mode, "taiko")
	t:eq(replay.nearest, true)
	t:eq(replay.const, true)
	t:eq(replay.created_at, 42)
	t:tdeq(replay.modifiers, {})
	t:eq(getmetatable(replay.timing_values), TimingValues)
	t:assert(valid.format(replay:validate()))
end

return test
