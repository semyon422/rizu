local class = require("class")
local Wave = require("audio.Wave")
local ChartAudio = require("rizu.engine.audio.ChartAudio")
local ISource = require("rizu.engine.audio.ISource")
local SoftwareMixer = require("rizu.engine.audio.SoftwareMixer")
local FakeProvider = require("rizu.engine.audio.fake.Provider")
local BassProvider = require("rizu.engine.audio.bass.Provider")

---@class rizu.audio.Engine
---@operator call: rizu.audio.Engine
---@field source rizu.audio.ISource
---@field foregroundSource rizu.audio.ISource
---@field provider rizu.audio.IProvider
local Engine = class()

Engine.music_volume = 1
Engine.keysounds_volume = 1

function Engine:new()
	---@type {[string]: audio.Wave}
	self.soundDataCache = {}
	self.mode = {primary = "bass_sample", secondary = "bass_sample"}
	self.source = ISource()
	self.foregroundSource = ISource()
	self.provider = FakeProvider()
end

---@param mode {primary: string, secondary: string}
function Engine:setAudioMode(mode)
	self.mode = mode
end

---@param enabled boolean
function Engine:setEnabled(enabled)
	if enabled then
		self.provider = BassProvider()
	else
		self.provider = FakeProvider()
	end
end

---@param chart chart.Chart
---@param resources {[string]: string}?
---@param auto_key_sound boolean?
function Engine:load(chart, resources, auto_key_sound)
	self.resources = resources or {}

	local use_tempo_secondary = self.mode.secondary == "bass_fx_tempo"
	self.foregroundSource = self.provider:createMixerSource(use_tempo_secondary)
	self.foregroundSource:setVolume(self.keysounds_volume)

	local chart_audio = ChartAudio()
	self.chart_audio = chart_audio

	chart_audio:load(chart, auto_key_sound)

	---@type {[integer]: rizu.audio.IDecoder}
	local decoders = {}
	for i, sound in ipairs(chart_audio.sounds) do
		local data = self.resources[sound.name]
		if data then
			decoders[i] = self.provider:createDecoder(data)
		end
	end

	self.mixer = SoftwareMixer(chart_audio.sounds, decoders)
	if not self.mixer.empty then
		local use_tempo = self.mode.primary == "bass_fx_tempo"
		self.source = self.provider:createChartSource(self.mixer, use_tempo)
		self.source:setVolume(self.music_volume)
	end
end

---@param name string
---@param volume number?
---@param offset number?
function Engine:playSample(name, volume, offset)
	if not self.resources then
		return
	end
	local data = self.resources[name]
	if not data then
		return
	end

	local decoder = self.provider:createDecoder(data)
	if offset and offset > 0 then
		decoder:setPosition(offset)
	end
	self.foregroundSource:addSound(decoder, volume)
end

function Engine:unload()
	if self.source then
		self.source:release()
		self.source = ISource()
	end

	if self.mixer then
		self.mixer:release()
		self.mixer = nil
	end

	if self.foregroundSource then
		self.foregroundSource:release()
		self.foregroundSource = ISource()
	end

	self.chart_audio = nil
	self.resources = nil
	self.soundDataCache = {}
end

---@return number
function Engine:getStartTime()
	local chart_audio = self.chart_audio
	if not chart_audio then
		return 0
	end
	return chart_audio:getStartTime()
end

---@return audio.Wave
function Engine:renderWave()
	local mixer = self.mixer
	local position = mixer:getPosition()
	local start_time = mixer:getTimeBounds()
	mixer:setPosition(start_time)

	local wave = Wave()
	wave:initBuffer(mixer:getChannelCount(), mixer:getSamplesDuration())
	mixer:getData(wave.byte_ptr, mixer:getBytesDuration())
	mixer:setPosition(position)
	return wave
end

---@return number?
function Engine:getPosition()
	return self.source:getPosition()
end

function Engine:update()
	self.source:update()
	self.foregroundSource:update()
end

function Engine:play()
	self.source:play()
	self.foregroundSource:play()
end

function Engine:pause()
	self.source:pause()
	self.foregroundSource:pause()
end

---@param rate number
function Engine:setRate(rate)
	self.source:setRate(rate)
	self.foregroundSource:setRate(rate)
end

---@param music_volume number
---@param keysounds_volume number
function Engine:setVolume(music_volume, keysounds_volume)
	self.music_volume = music_volume
	self.keysounds_volume = keysounds_volume
	self.source:setVolume(music_volume)
	self.foregroundSource:setVolume(keysounds_volume)
end

---@param position number
function Engine:setPosition(position)
	self.source:setPosition(position)
	-- Hitsounds usually don't seek with the song position,
	-- but we can reset the foreground mixer if needed.
	-- Currently we just let it be.
end

return Engine
