local ModeNotes = require("chart.model.ModeNotes")
local Rules = require("rizu.gameplay.taiko.Rules")
local Input = require("rizu.gameplay.taiko.Input")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local ReplayStore = require("rizu.gameplay.aim.ReplayStore")
local FakeFilesystem = require("fs.FakeFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local ScoreSaver = require("rizu.gameplay.ScoreSaver")
local test = {}

---@return chart.osu.TaikoChart
local function chart()
	return {overall_difficulty = 5, objects = {
		{time = 1, end_time = 1, kind = "note", color = "don", big = true, target = 1, sounds = {}},
		{time = 2, end_time = 3, kind = "roll", color = "don", big = false, target = 4, sounds = {}},
		{time = 4, end_time = 5, kind = "spinner", color = "don", big = false, target = 5, sounds = {}},
	}}
end

---@return rizu.RhythmEngine
---@return rizu.GameplaySession
local function session()
	local res = TestChartFactory():create("4key", {{time = 1, column = 1}})
	ModeNotes.write(res.chart, res.chart.layers.main, res.chart.layers.main.visuals[""], "taiko", chart())
	res.chart:compute()
	res.chartmeta.mode = "taiko"
	res.chartmeta.hash, res.chartmeta.index = ("a"):rep(32), 1
	local engine = RhythmEngine()
	engine:setChart(res.chart, res.chartmeta, res.chartdiff)
	engine:load(); engine:setGlobalTime(0); engine:setTime(-1)
	engine:setPlayTime(1, 5); engine:setRate(1.5); engine:setInputOffset(0.031); engine:play()
	return engine, GameplaySession(engine)
end

---@param t testing.T
function test.manual_actions_persist_and_replay_with_offset_and_rate(t)
	local engine, manual = session()
	for _, frame in ipairs(Rules.autoplay(chart())) do
		manual:receive(frame.event, (frame.time + 1 + 0.031) / 1.5)
	end
	manual:update(5)
	t:eq(engine.taiko_rules.hits, 3)
	t:eq(manual:hasResult(), false)
	t:has_error(function() ScoreSaver.saveScore({}, manual) end)
	local fs = FakeFilesystem()
	local store = ReplayStore(fs, "taiko")
	local path = store:save(manual)
	t:eq(path, "userdata/replays/taiko/" .. engine.chartmeta.hash .. "_1.json")
	local data, frames = store:load(engine.chartmeta.hash, 1)
	t:eq(data.format, "rizu-taiko-1")
	t:eq(data.input_offset, 0.031)
	t:eq(data.rate, 1.5)
	for _, step in ipairs({1 / 30, 1 / 144, 0.37, 5}) do
		local re, replay = session()
		replay:setPlayType("replay"); replay:setReplayFrames(frames)
		for time = step, 5 + step, step do replay:update(time) end
		t:tdeq(re.taiko_rules.events, engine.taiko_rules.events)
	end
	for _, mode in ipairs({"aim", "catch"}) do
		local wrong = ReplayStore(fs, mode)
		fs:createDirectory(wrong.directory)
		fs:write(wrong:path(engine.chartmeta.hash, 1), assert(fs:read(path)))
		t:has_error(function() wrong:load(engine.chartmeta.hash, 1) end)
	end
end

---@param t testing.T
function test.paused_input_is_recorded_as_state_only(t)
	local engine, manual = session()
	manual:pause()
	manual:receive(VirtualInputEvent(1, true, 1), 1)
	manual:receive(VirtualInputEvent(2, true, 1), 2)
	t:eq(engine.taiko_rules.hits, 0)
	local frames = manual.replay_recorder:getFrames()
	t:eq(frames[1].event.column, 2)
	t:eq(frames[2].event.column, 2)
	t:eq(frames[1].time, frames[2].time)
	local re, replay = session()
	replay:setPlayType("replay"); replay:setReplayFrames(frames)
	replay:update(5)
	t:eq(re.taiko_rules.hits, 0)
end

---@param t testing.T
function test.four_keys_keep_hand_identity(t)
	for id, key in ipairs({"f", "j", "d", "k"}) do
		local event = Input.transform({name = "keypressed", key})
		t:eq(event.id, id)
		t:eq(event.value, true)
		t:eq(Input.transform({name = "keyreleased", key}).value, false)
	end
	t:eq(Input.transform({name = "keypressed", "a"}), nil)
end

return test
