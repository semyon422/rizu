local AudioEngine = require("rizu.engine.audio.Engine")
local OffsetController = require("sphere.controllers.gameplay.OffsetController")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local GameplaySession = require("rizu.gameplay.GameplaySession")
local TestChartFactory = require("sea.chart.TestChartFactory")
local ComputeContext = require("sea.compute.ComputeContext")
local TimingValues = require("sea.chart.TimingValues")
local Timings = require("sea.chart.Timings")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

local test = {}

---@param format string?
---@return sphere.OffsetController, rizu.config.Config, table, rizu.audio.Engine, table
local function fixture(format)
	local settings = Settings.createConfig(FakeFilesystem())
	local context = {chartmeta = {hash = ("a"):rep(32), index = 1, format = format or "osu"}}
	local data = {local_offset = 0.03, rating = 0.8, comment = "keep"}
	local repo = {
		getUserChartmetaUserData = function() return data end,
		updateChartmetaUserData = function() end,
		updateChartmetaUserDataFull = function() end,
	}
	local audio = AudioEngine()
	local source = {
		position = 2.04,
		getPosition = function(self) return self.position end,
		setPosition = function(self, position) self.position = position end,
	}
	audio.source = source
	audio.output = {
		getPosition = function(_, position) return position - 0.04 end,
		clear = function() error("audio offset must not clear output") end,
		update = function() error("audio offset must not refill output") end,
	}
	local controller = OffsetController({chartsRepo = repo}, context, settings)
	controller:setRhythmEngine({audio_engine = audio})
	return controller, settings, context, audio, data
end

---@param t testing.T
function test.composes_and_updates_universal_format_and_chart_audio_offsets(t)
	local controller, settings, context, audio, data = fixture()
	local keys = Settings.keys
	t:aeq(audio.offset, -0.02 + 0.02 + 0.03, 1e-9)
	t:aeq(audio:getPosition(), 2, 1e-9)
	settings:setNumber(keys.gameplay.offset_audio_mode.bass_fx_tempo, 0.1)
	t:aeq(audio.offset, 0.15, 1e-9)
	t:aeq(audio:getPosition(), 2, 1e-9)
	settings:setNumber(keys.gameplay.offset_format.osu, -0.2)
	t:aeq(audio.offset, -0.07, 1e-9)
	t:aeq(audio:getPosition(), 2, 1e-9)
	settings:setChoice(keys.audio.mode_primary, "bass_sample")
	t:aeq(audio.offset, -0.17, 1e-9)
	settings:setNumber(keys.gameplay.offset_audio_mode.bass_sample, 0.05)
	t:aeq(audio.offset, -0.12, 1e-9)
	controller:increaseLocalOffset(0.001)
	t:aeq(data.local_offset, 0.031, 1e-9)
	t:aeq(audio.offset, -0.119, 1e-9)
	controller:resetLocalOffset()
	t:eq(data.local_offset, nil)
	t:aeq(audio.offset, -0.15, 1e-9)
	t:aeq(audio:getPosition(), 2, 1e-9)
	t:eq(data.rating, 0.8)
	t:eq(data.comment, "keep")
	context.chartmeta.format = "bms"
	controller:updateAudioOffset()
	t:aeq(audio.offset, 0.05, 1e-9)
	controller:unload()
end

---@param t testing.T
function test.maps_decoder_format_names_to_existing_json_keys(t)
	for _, format in ipairs({"osu", "quaver", "stepmania", "ksm", "bms", "iidx"}) do
		local controller, settings, _, audio = fixture(format)
		local keys = Settings.keys.gameplay
		settings:setNumber(keys.offset_audio_mode.bass_fx_tempo, 0.01)
		local format_key = keys.offset_format[format]
		if format_key then settings:setNumber(format_key, 0.07) end
		t:aeq(audio.offset, 0.01 + (format_key and 0.07 or 0) + 0.03, 1e-9)
		t:aeq(audio:getPosition(), 2, 1e-9)
		controller:unload()
	end
end

---@param t testing.T
function test.defers_before_chart_and_unsubscribes_on_unload(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local context = {}
	local controller = OffsetController({chartsRepo = {}}, context, settings)
	local calls = 0
	controller:setRhythmEngine({audio_engine = {setOffset = function() calls = calls + 1 end}})
	settings:setNumber(Settings.keys.gameplay.offset_audio_mode.bass_sample, 0.123)
	t:eq(calls, 0)
	controller:unload()
	settings:setNumber(Settings.keys.gameplay.offset_audio_mode.bass_sample, 0.234)
	t:eq(calls, 0)
end

---@param t testing.T
function test.audio_settings_changes_preserve_live_and_recomputed_score(t)
	for _, rate in ipairs({0.5, 1, 1.5, 2}) do
		local chart = TestChartFactory():create("4key", {{time = 1, column = 1}, {time = 2, column = 2}})
		chart.chartmeta.format = "osu"
		local function engine()
			local re = RhythmEngine()
			re:setChart(chart.chart, chart.chartmeta, chart.chartdiff)
			re:load()
			re:setAudioEnabled(false)
			re:setTimings(Timings("iidx"))
			re:setTimingValues(TimingValues():setSimple(0.25))
			re:setRate(rate)
			re:setGlobalTime(0)
			re:play()
			re:setTime(0)
			return re
		end
		local re = engine()
		local source = {
			position = 0.04,
			getPosition = function(self) return self.position end,
			setPosition = function(self, position) self.position = position end,
			update = function() end,
		}
		re.audio_engine.source = source
		re.audio_engine.output = {
			getPosition = function(_, position) return position - 0.04 end,
			update = function() end,
		}
		re.time_engine:setAdjustFunction(function() return re.audio_engine:getPosition() end)
		local settings = Settings.createConfig(FakeFilesystem())
		local controller = OffsetController({chartsRepo = {
			getUserChartmetaUserData = function() return {local_offset = 0.03} end,
		}}, {chartmeta = chart.chartmeta}, settings)
		controller:setRhythmEngine(re)
		local session = GameplaySession(re)
		source.position = 1.01 + re.audio_engine.offset + 0.04
		session:update(1.01 / rate)
		session:receive(VirtualInputEvent(1, true, 1), 1.01 / rate)
		local previous_time = re:getTime()
		settings:setNumber(Settings.keys.gameplay.offset_audio_mode.bass_fx_tempo, 0.123)
		settings:setNumber(Settings.keys.gameplay.offset_format.osu, -0.234)
		t:aeq(re:getTime(), previous_time, 1e-9)
		t:aeq(re.audio_engine:getPosition(), previous_time, 1e-9)
		t:aeq(re.logic_info.time, previous_time, 1e-9)
		t:aeq(re.visual_info.time, previous_time, 1e-9)
		source.position = 1.99 + re.audio_engine.offset + 0.04
		session:update(1.99 / rate)
		session:receive(VirtualInputEvent(2, true, 2), 1.99 / rate)
		local computed = engine()
		local frames = session.replay_recorder:getFrames()
		ComputeContext():computePlay(computed, frames)
		t:eq(#frames, 2)
		t:eq(#computed.score_engine.events, 2)
		for i, hit in ipairs(re.score_engine.events) do
			t:aeq(hit.time, frames[i].time, 1e-9)
			t:aeq(hit.time, computed.score_engine.events[i].time, 1e-9)
			t:aeq(hit.delta_time, computed.score_engine.events[i].delta_time, 1e-9)
		end
		t:eq(re.score_engine.scores.iidx:getScore(), computed.score_engine.scores.iidx:getScore())
		controller:unload()
	end
end

return test
