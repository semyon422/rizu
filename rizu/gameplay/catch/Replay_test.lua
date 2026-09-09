local ReplayStore = require("rizu.gameplay.aim.ReplayStore")
local ReplayRecorder = require("rizu.engine.replay.ReplayRecorder")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local FakeFilesystem = require("fs.FakeFilesystem")
local Input = require("rizu.gameplay.catch.Input")
local test = {}

---@param t testing.T
function test.catch_input_and_replay_are_separate_from_aim(t)
	local fs = FakeFilesystem()
	local catch = ReplayStore(fs, "catch")
	local aim = ReplayStore(fs)
	local recorder = ReplayRecorder()
	local event = Input.transform({name = "keypressed", "rshift"})
	t:eq(event.id, 6)
	t:eq(event.value, true)
	t:eq(Input.transform({name = "mousepressed", 1}), nil)
	recorder:record(-2, VirtualInputEvent(6, true, 2))
	recorder:record(1, VirtualInputEvent(6, false, 1))
	local hash = ("c"):rep(32)
	local session = {play_type = "manual", replay_recorder = recorder,
		rhythm_engine = {catch_rules = {}, chartmeta = {hash = hash, index = 1},
			time_engine = {timer = {rate = 1.5}}, logic_offset = 0.031}}
	local path = catch:save(session)
	t:eq(path, "userdata/replays/catch/" .. hash .. "_1.json")
	local data, frames = catch:load(hash, 1)
	t:eq(data.format, "rizu-catch-1")
	t:tdeq(frames, recorder:getFrames())
	fs:createDirectory(aim.directory)
	fs:write(aim:path(hash, 1), assert(fs:read(path)))
	t:has_error(function() aim:load(hash, 1) end)
	for _, invalid in ipairs({VirtualInputEvent(0, true, 1), VirtualInputEvent(2, nil, 1)}) do
		recorder.frames = {}
		recorder:record(0, invalid)
		catch:save(session)
		t:has_error(function() catch:load(hash, 1) end)
	end
end

return test
