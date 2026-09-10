local ModeNotes = require("chart.model.ModeNotes")
local Rules = require("rizu.gameplay.catch.Rules")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
local TestChartFactory = require("sea.chart.TestChartFactory")
local test = {}

---@return chart.osu.CatchChart
local function chart()
	return {circle_size = 5, approach_rate = 5, objects = {
		{time = 1, x = 100, kind = "fruit", sounds = {}},
		{time = 1.1, x = 450, kind = "fruit", sounds = {}},
		{time = 2, x = 300, kind = "droplet", sounds = {}},
		{time = 2.2, x = 300, kind = "tiny", sounds = {}},
	}}
end

---@param t testing.T
function test.autoplay_earns_hyperdash_without_position_teleport(t)
	local c = chart()
	local rules = Rules(c)
	t:eq(rules.hyper_targets[1], 2)
	for _, frame in ipairs(Rules.autoplay(c)) do
		t:eq(frame.event.pos, nil)
		rules:receive(frame.event, frame.time)
	end
	rules:update(4)
	t:eq(rules.hits, 3)
	t:eq(rules.misses, 0)
	t:eq(rules.bonus_hits, 1)
end

---@param t testing.T
function test.movement_boundaries_dash_and_independent_sources(t)
	local rules = Rules(chart())
	rules:receive(VirtualInputEvent(1, true, 1), 0)
	rules:receive(VirtualInputEvent(4, true, 1), 0)
	rules:receive(VirtualInputEvent(1, false, 1), 0)
	rules:update(0.2)
	t:aeq(rules.x, 156, 1e-8)
	rules:receive(VirtualInputEvent(3, true, 1), 0.2)
	rules:update(0.4)
	t:eq(rules.x, 0)
	rules:receive(VirtualInputEvent(2, true, 1), 0.4)
	rules:update(0.5)
	t:eq(rules.x, 0)
end

---@param t testing.T
function test.recorded_actions_replay_at_different_frame_rates(t)
	---@return rizu.RhythmEngine
	---@return rizu.GameplaySession
	local function session()
		local res = TestChartFactory():create("4key", {{time = 1, column = 1}})
		ModeNotes.write(res.chart, res.chart.layers.main, res.chart.layers.main.visuals[""], "catch", chart())
		res.chart:compute()
		res.chartmeta.mode = "catch"
		local re = RhythmEngine()
		re:setChart(res.chart, res.chartmeta, res.chartdiff)
		re:load(); re:setInputOffset(0.031); re:setRate(1.5); re:setPlayTime(0, 4); re:setGlobalTime(0); re:setTime(-1); re:play()
		return re, GameplaySession(re)
	end
	local re, manual = session()
	for _, frame in ipairs(Rules.autoplay(chart())) do manual:receive(frame.event, (frame.time + 1 + 0.031) / 1.5) end
	manual:update(5)
	t:eq(re.catch_rules.hits, 3)
	t:eq(manual:hasResult(), false)
	local frames = ReplayFrames.decode(ReplayFrames.encode(manual.replay_recorder:getFrames()))
	for _, step in ipairs({1 / 30, 1 / 144, 0.37, 5}) do
		local engine, replay = session()
		replay:setPlayType("replay"); replay:setReplayFrames(frames)
		for time = step, 5 + step, step do replay:update(time) end
		t:eq(engine.catch_rules.hits, re.catch_rules.hits)
		t:eq(engine.catch_rules.misses, re.catch_rules.misses)
		for i, e in ipairs(engine.catch_rules.events) do
			t:eq(e.hit, re.catch_rules.events[i].hit)
			t:aeq(e.x, re.catch_rules.events[i].x, 1e-7)
		end
	end
end

---@param t testing.T
function test.backward_clock_correction_does_not_integrate_movement_twice(t)
	local rules = Rules(chart())
	rules:update(-2)
	rules:receive(VirtualInputEvent(2, true, 2), -2)
	rules:receive(VirtualInputEvent(3, true, 2), -2)
	rules:update(-1.95)
	rules:update(-1.97)
	rules:update(-1.9)
	t:aeq(rules.x, 356, 1e-7)
end

---@param t testing.T
function test.motion_is_independent_of_update_partition(t)
	---@param step number
	---@return rizu.catch.Judgement[]
	local function simulate(step)
		local rules = Rules(chart())
		local frames = Rules.autoplay(chart())
		local now = frames[1].time
		for _, frame in ipairs(frames) do
			while now + step < frame.time do
				now = now + step
				rules:update(now)
			end
			rules:receive(frame.event, frame.time)
			now = frame.time
		end
		rules:update(4)
		return rules.events
	end
	local expected = simulate(10)
	for _, step in ipairs({1 / 30, 1 / 144, 0.001}) do
		t:tdeq(simulate(step), expected)
	end
end

---@param t testing.T
function test.equal_time_objects_keep_autoplay_frames_ordered(t)
	local c = chart()
	table.insert(c.objects, 2, {time = 1, x = 100, kind = "tiny", sounds = {}})
	local rules = Rules(c)
	local previous = -math.huge
	for _, frame in ipairs(Rules.autoplay(c)) do
		t:assert(frame.time >= previous)
		previous = frame.time
		rules:receive(frame.event, frame.time)
	end
	rules:update(4)
	t:eq(rules.hits, 3)
	t:eq(rules.bonus_hits, 2)
end

return test
