local digest = require("digest")
local valid = require("valid")
local Replay = require("sea.replays.Replay")
local ReplayCoder = require("sea.replays.ReplayCoder")
local ReplayEvents = require("sea.replays.ReplayEvents")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

local chartfile_data = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0
- =1
]]

---@param t testing.T
function test.all(t)
	---@type rizu.ReplayFrame[]
	local frames = {
		{time = 0, event = VirtualInputEvent(1, true, 1)},
		{time = 1, event = VirtualInputEvent(1, false, 1)},
	}

	---@type sea.Replay
	local replay = {
		version = 2,
		timing_values = assert(TimingValuesFactory:get(Timings("sphere"))),
		frames = frames,
		created_at = 0,
		--
		hash = digest.hash("md5", chartfile_data, true),
		index = 1,
		modifiers = {},
		rate = 1,
		mode = "mania",
		--
		nearest = true,
		tap_only = false,
		timings = Timings("sphere"),
		subtimings = nil,
		healths = Healths("simple", 20),
		columns_order = nil,
		--
		custom = false,
		const = false,
		pause_count = 0,
		rate_type = "linear",
	}
	setmetatable(replay, Replay)

	t:assert(valid.format(replay:validate()))

	local replayfile_data = t:assert(ReplayCoder.encode(replay))

	local _replay = t:assert(ReplayCoder.decode(replayfile_data))

	if _replay then
		t:assert(valid.format(_replay:validate()))
		t:tdeq(_replay, replay)
	end
end

return test
