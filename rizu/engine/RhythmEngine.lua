local class = require("class")

local InputEngine = require("rizu.engine.input.InputEngine")
local ActiveInputNotes = require("rizu.engine.input.ActiveInputNotes")

local AudioEngine = require("rizu.engine.audio.Engine")
local TimeEngine = require("rizu.engine.time.TimeEngine")

local LogicInfo = require("rizu.engine.logic.LogicInfo")
local LogicEngine = require("rizu.engine.logic.LogicEngine")

local VisualInfo = require("rizu.engine.visual.VisualInfo")
local VisualEngine = require("rizu.engine.visual.VisualEngine")

local BgaEngine = require("rizu.engine.sprite.BgaEngine")

local PlayProgress = require("rizu.engine.PlayProgress")
local PauseCounter = require("rizu.engine.PauseCounter")

local ScoreEngine = require("rizu.engine.ScoreEngine")

---@class rizu.RhythmEngine
---@operator call: rizu.RhythmEngine
local RhythmEngine = class()

RhythmEngine.logic_offset = 0
RhythmEngine.visual_offset = 0

function RhythmEngine:new()
	self.logic_info = LogicInfo()

	self.logic_engine = LogicEngine(self.logic_info)

	self.active_input_notes = ActiveInputNotes(self.logic_engine.active_notes)
	self.input_engine = InputEngine(self.active_input_notes)

	self.visual_info = VisualInfo()
	self.visual_engine = VisualEngine(self.visual_info)
	self.bga_engine = BgaEngine(self.visual_info)

	self.auto_key_sound = true

	self.score_engine = ScoreEngine()
	function self.logic_info.on_note_change(change)
		self.score_engine:receive(change)
	end

	self.audio_engine = AudioEngine()

	self.time_engine = TimeEngine()

	self.play_progress = PlayProgress()
	self.pause_counter = PauseCounter()
end

function RhythmEngine:load()
	local chart = self.chart

	self.active_input_notes:setInputMap(chart.inputMode:getInputMap())
	self.logic_engine:load(chart)
	self.visual_engine:load(chart)
	self.score_engine:load(self.chartdiff)
	self.pause_counter:new()

	self.visual_info.logic_notes = self.logic_engine.linked_to_logic
end

---@param resources {[string]: string}
function RhythmEngine:loadAudio(resources)
	self.chart_resources = resources
	self.audio_engine:load(self.chart, resources, self.auto_key_sound)

	self.time_engine:setAdjustFunction(function()
		return self.audio_engine:getPosition()
	end)
end

---@param resources {[string]: string}
---@param resource_paths {[string|integer]: string}?
function RhythmEngine:loadVisuals(resources, resource_paths)
	self.bga_engine:load(self.chart, resources, resource_paths)
end

---@param enabled boolean
function RhythmEngine:setAutoKeySound(enabled)
	self.auto_key_sound = enabled
end

---@return boolean
function RhythmEngine:hasResult()
	local time_engine = self.time_engine
	local base = self.score_engine.scores.base
	local accuracy = self.score_engine.scores.normalscore.accuracyAdjusted

	return
		not time_engine.wind_up and
		time_engine.time >= self.play_progress.start_time and
		base.hitCount > 0 and
		accuracy > 0 and
		accuracy < math.huge
end

function RhythmEngine:unloadAudio()
	if self.audio_engine then
		self.audio_engine:unload()
	end
end

function RhythmEngine:unload()
	self:unloadAudio()
	self.audio_engine = nil

	if self.bga_engine then
		self.bga_engine:unload()
	end
	self.bga_engine = nil

	self.visual_engine = nil
	self.logic_engine = nil
	self.input_engine = nil
	self.time_engine = nil
	self.score_engine = nil
end

function RhythmEngine:update()
	self:syncTime()

	self.input_engine:update()
	self.logic_engine:update()
	self.visual_engine:update()
	self.bga_engine:update()
	self.audio_engine:update()
end

function RhythmEngine:syncTime()
	self.logic_info.time = self.time_engine.time - self.logic_offset
	self.visual_info.time = self.time_engine.time - self.visual_offset
end

---@param pending_resync boolean?
function RhythmEngine:play(pending_resync)
	self.time_engine:play()
	self.audio_engine:play()
	self.input_engine:resume()
	self.pause_counter:play(self.time_engine.time)
	self.pending_resync = pending_resync
end

function RhythmEngine:pause()
	self.time_engine:pause()
	self.audio_engine:pause()
	self.input_engine:pause()
	self.pause_counter:pause()
	self.pending_resync = false
end

---@param event rizu.VirtualInputEvent
function RhythmEngine:receive(event)
	self:syncTime()
	local input_note, catched = self.input_engine:receive(event)

	if not self.auto_key_sound and event.value == true and catched then
		local logic_note = input_note and input_note.logic_note

		if logic_note and logic_note.linked_note.startNote.data.sounds then
			for _, sound in ipairs(logic_note.linked_note.startNote.data.sounds) do
				self.audio_engine:playSample(sound[1], sound[2])
			end
		end
	end
end

---@param no_mono boolean?
---@return number
function RhythmEngine:getTime(no_mono)
	if no_mono then
		return self.time_engine.time_no_mono
	end
	return self.time_engine.time
end

function RhythmEngine:getProgress()
	return self.play_progress:get(self:getTime())
end

---@param chart chart.Chart
---@param chartmeta sea.Chartmeta
---@param chartdiff sea.Chartdiff
function RhythmEngine:setChart(chart, chartmeta, chartdiff)
	self.chart = chart
	self.chartmeta = chartmeta
	self.chartdiff = chartdiff
end

---@param timings sea.Timings?
---@param subtimings sea.Subtimings?
function RhythmEngine:setTimings(timings, subtimings)
	timings = assert(timings or self.chartmeta.timings)
	self.score_engine:createByTimings(timings, subtimings, true)
end

---@param timing_values sea.TimingValues
function RhythmEngine:setTimingValues(timing_values)
	self.logic_info.timing_values = timing_values
end

---@param rate number
function RhythmEngine:setRate(rate)
	self.logic_info.rate = rate
	self.time_engine:setRate(rate)
	self.audio_engine:setRate(rate)
end

---@param enabled boolean
function RhythmEngine:setAudioEnabled(enabled)
	self.audio_engine:setEnabled(enabled)
end

---@param nearest boolean
function RhythmEngine:setNearest(nearest)
	self.input_engine.nearest = nearest
end

---@param const boolean
function RhythmEngine:setConst(const)
	self.time_engine.const = const
	self.visual_info.const = const
end

---@param time number
function RhythmEngine:setGlobalTime(time)
	if not self.pending_resync then
		self.time_engine:setGlobalTime(time)
		return
	end

	self.pending_resync = false
	self.time_engine:pause()
	self.time_engine:setGlobalTime(time)
	self.bga_engine:seek(time)
	self.time_engine:play()
end

---@param adjust_factor number
function RhythmEngine:setAdjustFactor(adjust_factor)
	self.time_engine:setAdjustFactor(adjust_factor)
end

---@param visual_rate number
---@param scale_visual_rate boolean?
function RhythmEngine:setVisualRate(visual_rate, scale_visual_rate)
	if not scale_visual_rate then
		visual_rate = visual_rate / self.logic_info.rate
	end
	self.visual_info.rate = visual_rate
end

---@param volume {master: number, music: number, keysounds: number}
function RhythmEngine:setVolume(volume)
	self.audio_engine:setVolume(volume.master * volume.music, volume.master * volume.keysounds)
end

---@param time number
function RhythmEngine:setTime(time)
	self.audio_engine:setPosition(time)
	self.bga_engine:seek(time)
	self:setTimeNoAudio(time)
end

---@param time number
function RhythmEngine:setTimeNoAudio(time)
	self.time_engine:setTime(time)
	self:update()
end

---@param offset number
function RhythmEngine:setInputOffset(offset)
	self.logic_offset = offset
end

---@param column integer
---@return boolean
function RhythmEngine:isColumnPressed(column)
	return self.input_engine:isColumnPressed(column)
end

---@param offset number
function RhythmEngine:setVisualOffset(offset)
	self.visual_offset = offset
end

---@param shortening number
function RhythmEngine:setLongNoteShortening(shortening)
	self.visual_info.shortening = shortening
end

---@param time number
function RhythmEngine:setTimeToPrepare(time)
	self.prepare_time = time
	local start_time = self.play_progress.start_time
	local time_to_prepare = math.min(start_time - time, self.audio_engine:getStartTime())
	local init_time = time_to_prepare * self.logic_info.rate
	self:setTime(init_time)
	self.play_progress.init_time = init_time
end

---@param start_time number
---@param duration number
function RhythmEngine:setPlayTime(start_time, duration)
	self.play_progress.start_time = start_time
	self.play_progress.duration = duration
	self.pause_counter:setPlayTime(start_time, duration)
end

---@param audio_mode {primary: string, secondary: string}
function RhythmEngine:setAudioMode(audio_mode)
	self.audio_mode = audio_mode
	self.audio_engine:setAudioMode(audio_mode)
end

---@param wind_up string
function RhythmEngine:setWindUp(wind_up)
end

function RhythmEngine:skipIntro()
	local skip_to = self.play_progress.start_time - (self.prepare_time or 0)
	if self:getTime() < skip_to then
		self:setTime(skip_to)
	end
end

return RhythmEngine
