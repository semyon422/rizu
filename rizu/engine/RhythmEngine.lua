local class = require("class")

local AudioEngine = require("rizu.engine.audio.Engine")
local TimeEngine = require("rizu.engine.time.TimeEngine")
local VisualInfo = require("rizu.engine.visual.VisualInfo")
local BgaEngine = require("rizu.engine.sprite.BgaEngine")
local PlayProgress = require("rizu.engine.PlayProgress")
local PauseCounter = require("rizu.engine.PauseCounter")

---What every gamemode shares: time, audio, BGA, progress and pauses.
---Notes, judgement and scoring belong to the subclass of each gamemode.
---@class rizu.RhythmEngine
---@operator call: rizu.RhythmEngine
---@field chart chart.Chart
---@field chartmeta sea.Chartmeta
---@field chartdiff sea.Chartdiff
---@field mode sea.Gamemode
---@field marks_paused_input boolean Inputs received while paused are recorded on column 2.
local RhythmEngine = class()

RhythmEngine.marks_paused_input = false

function RhythmEngine:new()
	self.visual_info = VisualInfo()
	self.bga_engine = BgaEngine(self.visual_info)

	self.auto_key_sound = true
	self.rate = 1
	self.paused = false

	self.audio_engine = AudioEngine()

	self.time_engine = TimeEngine()

	self.play_progress = PlayProgress()
	self.pause_counter = PauseCounter()
end

---Builds gamemode state from the chart given to setChart.
function RhythmEngine:load() end

---Advances gamemode state to the current time.
function RhythmEngine:updateNotes() end

---Shifts judgement of manual input. Only modes that support it override this.
---@param offset number
function RhythmEngine:setInputOffset(offset) end

---Time on the judgement clock, which replays record and play back as is.
---@return number
function RhythmEngine:getLogicTime()
	return self.time_engine.time
end

---@param event rizu.VirtualInputEvent
function RhythmEngine:receive(event) end

---@return boolean
function RhythmEngine:hasResult()
	return false
end

---Modes without configurable timings keep their own windows.
---@param timings sea.Timings?
---@param subtimings sea.Subtimings?
---@param healths sea.Healths?
function RhythmEngine:setTimings(timings, subtimings, healths) end

---Scripted inputs for modes that autoplay through the replay player.
---@return rizu.ReplayFrame[]?
function RhythmEngine:getAutoplayFrames() end

---An input the mode needs replayed when the player pauses.
---@return rizu.VirtualInputEvent?
function RhythmEngine:getPauseEvent() end

---Extra time after the last object during which it can still be judged.
---@return number
function RhythmEngine:getPlayPadding()
	return 0
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

function RhythmEngine:unloadAudio()
	if self.audio_engine then
		self.audio_engine:unload()
	end
end

function RhythmEngine:unload()
	self:unloadAudio()
	self.audio_engine = nil

	if self.bga_engine then
		self.bga_engine:release()
	end
	self.bga_engine = nil

	self.time_engine = nil
end

function RhythmEngine:update()
	self:syncTime()
	self:updateNotes()
	self.bga_engine:update()
	self.audio_engine:update()
end

---@param samples {[1]: string, [2]: number}[]?
function RhythmEngine:playSamples(samples)
	if not samples then return end
	for _, sample in ipairs(samples) do
		self.audio_engine:playSample(sample[1], sample[2])
	end
end

function RhythmEngine:syncTime()
	self.visual_info.time = self.time_engine.time
end

---@param pending_resync boolean?
function RhythmEngine:play(pending_resync)
	self.time_engine:play()
	self.audio_engine:play()
	self.paused = false
	self.pause_counter:play(self.time_engine.time)
	self.pending_resync = pending_resync
end

function RhythmEngine:pause()
	self.time_engine:pause()
	self.audio_engine:pause()
	self.paused = true
	self.pause_counter:pause()
	self.pending_resync = false
end

---@return boolean
function RhythmEngine:isPaused()
	return self.paused
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
	self.mode = chartmeta.mode
end

---@param rate number
function RhythmEngine:setRate(rate)
	self.rate = rate
	self.time_engine:setRate(rate)
	self.audio_engine:setRate(rate)
end

---@param enabled boolean
function RhythmEngine:setAudioEnabled(enabled)
	self.audio_engine:setEnabled(enabled)
end

---@param time number
function RhythmEngine:setGlobalTime(time)
	if not self.pending_resync then
		self.time_engine:setGlobalTime(time)
		return
	end

	if time == self.time_engine.timer:getGlobalTime() then
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
		visual_rate = visual_rate / self.rate
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

---@param time number
function RhythmEngine:setTimeToPrepare(time)
	self.prepare_time = time
	local start_time = self.play_progress.start_time
	local time_to_prepare = math.min(start_time - time, self.audio_engine:getStartTime())
	local init_time = time_to_prepare * self.rate
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

function RhythmEngine:skipIntro()
	local skip_to = self.play_progress.start_time - (self.prepare_time or 0)
	if self:getTime() < skip_to then
		self:setTime(skip_to)
	end
end

return RhythmEngine
