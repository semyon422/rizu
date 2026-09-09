local json = require("json")
local ReplayStore = require("rizu.gameplay.aim.ReplayStore")
local ReplayRecorder = require("rizu.engine.replay.ReplayRecorder")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.local_replay_round_trip_without_score_or_hits(t)
	local fs = FakeFilesystem()
	local store = ReplayStore(fs)
	local hash = ("a"):rep(32)
	local recorder = ReplayRecorder()
	recorder:record(-1, VirtualInputEvent(0, nil, 1, {100, 200}))
	recorder:record(1, VirtualInputEvent(1, true, 2))
	local session = {
		play_type = "manual", replay_recorder = recorder,
		rhythm_engine = {
			aim_rules = {}, chartmeta = {hash = hash, index = 1},
			time_engine = {timer = {rate = 1.5}}, logic_offset = -0.025,
		},
	}
	local path = store:save(session)
	t:eq(path, "userdata/replays/aim/" .. hash .. "_1.json")
	local replay, frames = store:load(hash, 1)
	t:eq(replay.format, "rizu-aim-tracking-1")
	t:eq(replay.rate, 1.5)
	t:eq(replay.input_offset, -0.025)
	t:tdeq(frames, recorder:getFrames())
	local old = assert(json.decode(assert(fs:read(path))))
	old.format = "rizu-aim-circles-1"
	fs:write(path, assert(json.encode(old)))
	local legacy, legacy_frames = store:load(hash, 1)
	t:eq(legacy.format, "rizu-aim-circles-1")
	t:tdeq(legacy_frames, frames)
	old.format = "unknown-version"
	fs:write(path, assert(json.encode(old)))
	t:has_error(function() store:load(hash, 1) end)
	session.play_type = "replay"
	t:has_error(function() store:save(session) end)
	t:has_error(function() store:load(hash, 2) end)
	t:has_error(function() store:load("../invalid", 1) end)
end

return test
