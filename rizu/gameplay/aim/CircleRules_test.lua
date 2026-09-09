local CircleRules = require("rizu.gameplay.aim.CircleRules")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

---@return chart.osu.AimChart
local function chart()
	return {
		circle_size = 5, approach_rate = 5, overall_difficulty = 5,
		objects = {
			{time = 1, x = 100, y = 100, kind = "circle", sounds = {}},
			{time = 1, x = 300, y = 100, kind = "circle", sounds = {}},
			{time = 2, x = 200, y = 200, kind = "circle", sounds = {}},
		},
	}
end

---@param t testing.T
function test.spatial_hits_note_lock_and_deadlines(t)
	local rules = CircleRules(chart())
	rules:receive(VirtualInputEvent(1, true, 1, {300, 100}), 1)
	t:eq(rules.hits, 0)
	rules:receive(VirtualInputEvent(1, false, 1), 1)
	rules:receive(VirtualInputEvent(0, nil, 1, {100, 100}), 1)
	t:eq(rules.hits, 0)
	rules:receive(VirtualInputEvent(1, true, 1), 1)
	t:eq(rules.hits, 1)
	rules:receive(VirtualInputEvent(1, true, 1, {300, 100}), 1)
	t:eq(rules.hits, 1)
	rules:receive(VirtualInputEvent(2, true, 1), 1)
	t:eq(rules.hits, 2)
	rules:update(10)
	t:eq(rules.misses, 1)
	t:aeq(rules.events[3].time, 2.15, 1e-9)
end

---@param t testing.T
function test.paused_state_does_not_hit_or_press_again_on_resume(t)
	local rules = CircleRules(chart())
	rules:receive(VirtualInputEvent(1, true, 2, {100, 100}), 1)
	rules:receive(VirtualInputEvent(1, true, 1), 1)
	t:eq(rules.hits, 0)
	rules:receive(VirtualInputEvent(1, false, 1), 1)
	rules:receive(VirtualInputEvent(1, true, 1), 1)
	t:eq(rules.hits, 1)
end

---@param offset number
---@param rate number
---@return rizu.RhythmEngine
---@return rizu.GameplaySession
local function session(offset, rate)
	local res = TestChartFactory():create("4key", {{time = 1, column = 1}})
	res.chart.aim = chart()
	local re = RhythmEngine()
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:load()
	re:setInputOffset(offset)
	re:setRate(rate)
	re:setPlayTime(0, 4)
	re:setGlobalTime(0)
	re:play()
	return re, GameplaySession(re)
end

---@param t testing.T
function test.manual_recording_and_replay_match_at_different_rates_and_frames(t)
	for _, rate in ipairs({0.75, 1, 1.5}) do
		local offset = 0.031
		local re, manual = session(offset, rate)
		for _, frame in ipairs(CircleRules.autoplay(chart())) do
			manual:receive(frame.event, (frame.time + offset) / rate)
		end
		manual:update(5)
		t:eq(re.aim_rules.hits, 3)
		t:eq(manual:hasResult(), false)
		local frames = ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames()))
		for _, step in ipairs({1 / 30, 1 / 60, 1 / 144, 0.37, 5}) do
			local replay_re, replay = session(offset, rate)
			replay:setPlayType("replay")
			replay:setReplayFrames(frames)
			for time = step, 5 + step, step do
				replay:update(time)
			end
			t:tdeq(replay_re.aim_rules.events, re.aim_rules.events)
		end
	end
end

---@param t testing.T
function test.autoplay_uses_replay_input_and_recording_snapshots(t)
	local re, auto = session(0, 1)
	auto:setPlayType("auto")
	auto:update(5)
	t:eq(re.aim_rules.hits, 3)
	local _, manual = session(0, 1)
	local event = VirtualInputEvent(1, true, 1, {100, 100})
	manual:receive(event, 1)
	event.pos[1] = 999
	event.value = false
	t:eq(manual.replay_recorder.frames[1].event.pos[1], 100)
	t:eq(manual.replay_recorder.frames[1].event.value, true)
end

---@param t testing.T
function test.pause_recording_replays_without_spurious_hits(t)
	local re, manual = session(0.03, 1)
	manual:update(1.03)
	manual:pause()
	manual:receive(VirtualInputEvent(1, true, 1, {100, 100}), 2)
	t:eq(re.aim_rules.hits, 0)
	manual:play()
	manual:receive(VirtualInputEvent(1, false, 1), 2)
	manual:receive(VirtualInputEvent(1, true, 1, {100, 100}), 2)
	manual:update(5)
	local replay_re, replay = session(0.03, 1)
	replay:setPlayType("replay")
	replay:setReplayFrames(ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames())))
	replay:update(5)
	t:tdeq(replay_re.aim_rules.events, re.aim_rules.events)
	t:eq(re.aim_rules.hits, 1)
end

return test
