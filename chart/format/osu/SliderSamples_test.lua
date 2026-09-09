local RhythmEngine = require("rizu.engine.RhythmEngine")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local Chartdiff = require("sea.chart.Chartdiff")
local ChartDecoder = require("chart.format.osu.ChartDecoder")
local SliderSamples = require("chart.format.osu.SliderSamples")
local Sliders = require("rizu.gameplay.aim.Sliders")
local RefChart = require("chart.refchart.RefChart")
local Restorer = require("chart.refchart.Restorer")
local CircleRules = require("rizu.gameplay.aim.CircleRules")

local test = {}
local header = [[osu file format v14
[General]
Mode:0
SampleSet:Normal
[Difficulty]
CircleSize:4
OverallDifficulty:5
SliderMultiplier:1
SliderTickRate:1
[TimingPoints]
0,500,4,1,0,60,1,0
1400,-100,4,2,2,30,0,0
2400,-100,4,3,3,80,0,0
[HitObjects]
]]

---@param t testing.T
function test.edge_masks_sets_tick_samples_and_timing_changes(t)
	local chart = ChartDecoder():decode(header .. "100,100,1000,2,0,L|300:100,2,200,2|8|4,1:2|3:1|2:3,0:0:0:0:")[1].chart
	SliderSamples.prepare(chart.aim, Sliders.prepare(chart.aim), chart.resources)
	local source = chart.aim.objects[1].slider
	local head = chart.aim.objects[1].sounds
	t:eq(head[1][1], "normal-hitnormal")
	t:eq(head[2][1], "soft-hitwhistle")
	t:aeq(head[1][2], 0.48, 1e-9)
	local samples = source.checkpoint_sounds
	t:tdeq(samples[1], {{"soft-slidertick2", 0.3}})
	t:eq(samples[2][1][1], "drum-hitnormal2")
	t:eq(samples[2][2][1], "normal-hitclap2")
	t:tdeq(samples[3], {{"drum-slidertick3", 0.8}})
	t:eq(samples[4][1][1], "soft-hitnormal3")
	t:eq(samples[4][2][1], "drum-hitfinish3")
	t:tdeq(chart.resources.sound["soft-slidertick2"], {"soft-slidertick2", "soft-slidertick", "aim-slidertick"})
	local restored = Restorer():restore(RefChart(chart))
	t:tdeq(restored.aim, chart.aim)
	local rules = CircleRules(restored.aim)
	for _, frame in ipairs(CircleRules.autoplay(restored.aim)) do rules:receive(frame.event, frame.time) end
	rules:update(4)
	t:eq(rules.hits, 1)
	for i, event in ipairs(rules.checkpoint_events) do t:tdeq(event.sounds, samples[i]) end
end

---@param t testing.T
function test.custom_file_only_on_head_and_explicit_volume(t)
	local chart = ChartDecoder():decode(header .. "100,100,1000,2,0,L|300:100,1,200,0|8,0:0|0:0,3:2:4:50:custom.wav")[1].chart
	SliderSamples.prepare(chart.aim, Sliders.prepare(chart.aim), chart.resources)
	t:tdeq(chart.aim.objects[1].sounds, {{"custom.wav", 0.5}})
	local samples = chart.aim.objects[1].slider.checkpoint_sounds
	t:tdeq(samples[1], {{"drum-slidertick4", 0.5}})
	t:eq(samples[2][1][1], "drum-hitnormal4")
	t:eq(samples[2][2][1], "soft-hitclap4")
end

---@param t testing.T
function test.first_sample_bank_and_zero_volume(t)
	local source = header:gsub("0,500,4,1,0,60", "0,500,4,1,1,0")
	local chart = ChartDecoder():decode(source .. "100,100,1000,2,8,L|300:100,1,200")[1].chart
	SliderSamples.prepare(chart.aim, Sliders.prepare(chart.aim), chart.resources)
	t:eq(chart.aim.objects[1].sounds[1][1], "normal-hitnormal")
	t:eq(chart.aim.objects[1].sounds[1][2], 0)
	t:eq(chart.aim.objects[1].sounds[2][2], 0)
end

---@param t testing.T
function test.engine_dispatches_each_successful_sample_once(t)
	local decoded = ChartDecoder():decode(header .. "100,100,1000,2,0,L|300:100,2,200,2|8|4,1:2|3:1|2:3,0:0:0:0:")[1]
	local chart = decoded.chart
	SliderSamples.prepare(chart.aim, Sliders.prepare(chart.aim), chart.resources)
	local re = RhythmEngine()
	re:setChart(chart, decoded.chartmeta, Chartdiff())
	re:load()
	---@type string[]
	local played = {}
	re.audio_engine.playSample = function(_, name) played[#played + 1] = name end
	re:setPlayTime(0, 4)
	re:setGlobalTime(0)
	re:play()
	local session = GameplaySession(re)
	session:setPlayType("auto")
	session:update(4)
	t:tdeq(played, {"normal-hitnormal", "soft-hitwhistle", "soft-slidertick2", "drum-hitnormal2",
		"normal-hitclap2", "drum-slidertick3", "soft-hitnormal3", "drum-hitfinish3"})
	session:update(5)
	t:eq(#played, 8)
end

return test
