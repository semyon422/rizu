local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local Rules = require("rizu.gameplay.sdvx.Rules")
local SdvxChart = require("chart.format.ksm.SdvxChart")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local ReplayStore = require("rizu.gameplay.aim.ReplayStore")
local FakeFilesystem = require("fs.FakeFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")
local ScoreSaver = require("rizu.gameplay.ScoreSaver")
local test = {}

local source = [[t=120
--
2000|20|0o
2000|00|::
0000|00|o0
0000|00|--
--
]]

---@return rizu.RhythmEngine
---@return rizu.GameplaySession
local function session()
	local res = TestChartFactory():create("4key", {{time = 1, column = 1}})
	res.chart.sdvx = SdvxChart(source)
	res.chartmeta.mode = "sdvx"
	res.chartmeta.hash, res.chartmeta.index = ("a"):rep(32), 1
	local re = RhythmEngine()
	re:setChart(res.chart, res.chartmeta, res.chartdiff)
	re:load(); re:setGlobalTime(0); re:setTime(-1)
	re:setPlayTime(0, 3); re:setRate(1.5); re:setInputOffset(0.031); re:play()
	return re, GameplaySession(re)
end

---@param t testing.T
function test.manual_session_replays_lasers_and_buttons_with_rate_offset(t)
	local re, manual = session()
	for _, frame in ipairs(Rules.autoplay(re.sdvx_rules.chart)) do
		manual:receive(frame.event, (frame.time + 1 + 0.031) / 1.5)
	end
	manual:update(4)
	t:eq(re.sdvx_rules.hits, 2)
	t:eq(manual:hasResult(), false)
	t:has_error(function() ScoreSaver.saveScore({}, manual) end)
	local fs = FakeFilesystem()
	local store = ReplayStore(fs, "sdvx")
	store:save(manual)
	local data, frames = store:load(re.chartmeta.hash, 1)
	t:eq(data.format, "rizu-sdvx-1")
	for _, step in ipairs({1 / 30, 1 / 144, 0.37, 4}) do
		local engine, replay = session()
		replay:setPlayType("replay"); replay:setReplayFrames(frames)
		for time = step, 4 + step, step do replay:update(time) end
		t:tdeq(engine.sdvx_rules.button_rules.events, re.sdvx_rules.button_rules.events)
		for i, laser in ipairs(engine.sdvx_rules.lasers) do
			t:tdeq(laser.ticks, re.sdvx_rules.lasers[i].ticks)
			t:tdeq(laser.slams, re.sdvx_rules.lasers[i].slams)
		end
	end
	for _, mode in ipairs({"aim", "catch", "taiko"}) do
		local wrong = ReplayStore(fs, mode)
		fs:createDirectory(wrong.directory)
		fs:write(wrong:path(re.chartmeta.hash, 1), assert(fs:read(store:path(re.chartmeta.hash, 1))))
		t:has_error(function() wrong:load(re.chartmeta.hash, 1) end)
	end
end

---@param t testing.T
function test.paused_actions_and_relative_turns_validate_in_store(t)
	local re, manual = session()
	manual:pause()
	manual:receive(VirtualInputEvent(8, true, 1), 0)
	manual:receive(VirtualInputEvent(11, nil, 1, {0.02, 0}), 0)
	local store = ReplayStore(FakeFilesystem(), "sdvx")
	store:save(manual)
	local _, frames = store:load(re.chartmeta.hash, 1)
	t:eq(frames[1].event.column, 2)
	t:eq(frames[2].event.column, 2)
	t:eq(frames[2].event.pos[1], 0.02)
	for _, event in ipairs({VirtualInputEvent(0, true, 1), VirtualInputEvent(11, true, 1), VirtualInputEvent(12, nil, 1, {0.1, 2})}) do
		manual.replay_recorder.frames = {}
		manual.replay_recorder:record(0, event)
		store:save(manual)
		t:has_error(function() store:load(re.chartmeta.hash, 1) end)
	end
end

return test
