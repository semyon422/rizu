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
---@param aim chart.osu.AimChart?
local function session(offset, rate, aim)
	local res = TestChartFactory():create("4key", {{time = 1, column = 1}})
	res.chart.aim = aim or chart()
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

---@return chart.osu.AimChart
local function sliderChart()
	local aim = chart()
	aim.format_version, aim.slider_multiplier, aim.slider_tick_rate = 14, 1, 1
	aim.timing_points = {{offset = 0, beatLength = 500}}
	aim.objects = {{time = 1, x = 100, y = 100, kind = "slider", sounds = {},
		slider = {curve_type = "L", controls = {{100, 100}, {400, 100}}, length = 300, spans = 2}},
		{time = 5, x = 100, y = 100, kind = "circle", sounds = {}}}
	return aim
end

---@param t testing.T
function test.slider_autoplay_manual_and_binary_replay_match(t)
	local aim = sliderChart()
	for _, rate in ipairs({0.75, 1, 1.5}) do
		local offset = 0.031
		local re, manual = session(offset, rate, aim)
		for _, frame in ipairs(CircleRules.autoplay(aim)) do
			manual:receive(frame.event, (frame.time + offset) / rate)
		end
		manual:update(10)
		t:eq(re.aim_rules.hits, 2)
		t:eq(re.aim_rules.checkpoint_hits, 6)
		t:eq(re.aim_rules.checkpoint_misses, 0)
		local frames = ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames()))
		for _, step in ipairs({1 / 30, 1 / 144, 0.37, 10}) do
			local engine, replay = session(offset, rate, aim)
			replay:setPlayType("replay")
			replay:setReplayFrames(frames)
			for time = step, 10 + step, step do replay:update(time) end
			t:tdeq(engine.aim_rules.events, re.aim_rules.events)
			t:tdeq(engine.aim_rules.checkpoint_events, re.aim_rules.checkpoint_events)
		end
	end
end

---@param t testing.T
function test.slider_can_recover_checkpoints_but_not_full_object_hit(t)
	local rules = CircleRules(sliderChart())
	rules:receive(VirtualInputEvent(1, true, 1, {100, 100}), 1)
	rules:receive(VirtualInputEvent(1, false, 1), 1.4)
	rules:update(1.6)
	t:eq(rules.checkpoint_misses, 1)
	rules:receive(VirtualInputEvent(2, true, 1, {300, 100}), 2)
	rules:receive(VirtualInputEvent(0, nil, 1, {400, 100}), 2.5)
	rules:receive(VirtualInputEvent(0, nil, 1, {300, 100}), 3)
	rules:receive(VirtualInputEvent(0, nil, 1, {200, 100}), 3.5)
	rules:receive(VirtualInputEvent(0, nil, 1, {100, 100}), 4)
	rules:update(4.1)
	t:eq(rules.misses, 1)
	t:eq(rules.checkpoint_hits, 5)
end

---@param t testing.T
function test.slider_body_does_not_lock_later_heads(t)
	local aim = sliderChart()
	aim.objects[2].time = 2
	local rules = CircleRules(aim)
	rules:receive(VirtualInputEvent(1, true, 1, {100, 100}), 1)
	rules:receive(VirtualInputEvent(2, true, 1, {100, 100}), 2)
	t:eq(rules.heads[2], "hit")
	t:eq(rules.states[1], nil)
	t:eq(rules.states[2], "hit")
end

---@param t testing.T
function test.slider_pause_release_round_trip(t)
	local aim = sliderChart()
	local re, manual = session(0, 1, aim)
	manual:receive(VirtualInputEvent(1, true, 1, {100, 100}), 1)
	manual:update(1.5)
	manual:pause()
	manual:receive(VirtualInputEvent(1, false, 1, {200, 100}), 2)
	manual:play()
	manual:update(6)
	local engine, replay = session(0, 1, aim)
	replay:setPlayType("replay")
	replay:setReplayFrames(ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames())))
	replay:update(10)
	t:tdeq(engine.aim_rules.events, re.aim_rules.events)
	t:tdeq(engine.aim_rules.checkpoint_events, re.aim_rules.checkpoint_events)
	t:eq(re.aim_rules.checkpoint_hits, 0)
end

---@return chart.osu.AimChart
local function spinnerChart()
	local aim = chart()
	aim.objects = {
		{time = 1, end_time = 3, x = 256, y = 192, kind = "spinner", sounds = {}},
		{time = 3, x = 100, y = 100, kind = "circle", sounds = {}},
	}
	return aim
end

---@param t testing.T
function test.spinner_autoplay_and_manual_binary_replay(t)
	local aim = spinnerChart()
	for _, rate in ipairs({0.75, 1, 1.5}) do
		local offset = 0.031
		local re, manual = session(offset, rate, aim)
		for _, frame in ipairs(CircleRules.autoplay(aim)) do manual:receive(frame.event, (frame.time + offset) / rate) end
		manual:update(10)
		t:eq(re.aim_rules.hits, 2)
		local frames = ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames()))
		for _, step in ipairs({1 / 30, 1 / 144, 0.37, 10}) do
			local engine, replay = session(offset, rate, aim)
			replay:setPlayType("replay")
			replay:setReplayFrames(frames)
			for time = step, 10 + step, step do replay:update(time) end
			t:tdeq(engine.aim_rules.events, re.aim_rules.events)
			t:eq(engine.aim_rules.spinners[1].angle_sum, re.aim_rules.spinners[1].angle_sum)
		end
	end
	local engine, auto = session(0, 1, aim)
	auto:setPlayType("auto")
	auto:update(10)
	t:eq(engine.aim_rules.hits, 2)
end

---@param t testing.T
function test.spinner_no_input_misses_and_expiry_is_inclusive(t)
	local rules = CircleRules(spinnerChart())
	rules:update(3)
	t:eq(rules.states[1], nil)
	rules:receive(VirtualInputEvent(1, true, 1, {100, 100}), 3)
	t:eq(rules.states[2], "hit")
	rules:update(4)
	t:eq(rules.states[1], "miss")
	t:eq(rules.events[2].time, 3)
end

---@param t testing.T
function test.spinner_pause_without_motion_resets_replay_baseline(t)
	local aim = spinnerChart()
	local re, manual = session(0, 1, aim)
	manual:receive(VirtualInputEvent(1, true, 1, {356, 192}), 1)
	manual:receive(VirtualInputEvent(0, nil, 1, {256, 292}), 1.1)
	manual:pause()
	t:eq(re.aim_rules.spinners[1].last_angle, nil)
	manual:play()
	manual:receive(VirtualInputEvent(0, nil, 1, {156, 192}), 1.2)
	t:aeq(re.aim_rules.spinners[1]:getTurns(), 0.25, 1e-9)
	manual:update(10)
	local engine, replay = session(0, 1, aim)
	replay:setPlayType("replay")
	replay:setReplayFrames(ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames())))
	replay:update(10)
	t:tdeq(engine.aim_rules.events, re.aim_rules.events)
	t:eq(engine.aim_rules.spinners[1].angle_sum, re.aim_rules.spinners[1].angle_sum)
end

return test
