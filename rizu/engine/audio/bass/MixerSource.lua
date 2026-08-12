local ISource = require("rizu.engine.audio.ISource")
local bass = require("bass")
local bass_mix = require("bass.mix")
local bass_fx = require("bass.fx")
local bass_flags = require("bass.flags")
local bass_assert = require("bass.assert")

---@class rizu.audio.bass.MixerSource: rizu.audio.ISource
---@operator call: rizu.audio.bass.MixerSource
local MixerSource = ISource + {}

---@param use_tempo boolean?
function MixerSource:new(use_tempo)
	self.use_tempo = use_tempo
	self.sample_rate = 44100

	local flags = bass_flags.BASS_MIXER_NONSTOP
	if use_tempo then
		flags = flags + bass_flags.BASS_STREAM_DECODE
	end

	---@type integer
	self.mixer_channel = bass_mix.BASS_Mixer_StreamCreate(self.sample_rate, 2, flags)
	bass_assert(self.mixer_channel ~= 0)

	if use_tempo then
		self.channel = bass_fx.BASS_FX_TempoCreate(self.mixer_channel, bass_flags.BASS_FX_FREESOURCE)
		bass_assert(self.channel ~= 0)
	else
		self.channel = self.mixer_channel
	end

	-- Reduce playback buffer to minimum for lowest latency
	bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_BUFFER, 0)

	bass.BASS_ChannelPlay(self.channel, false)

	---@type {decoder: rizu.audio.bass.Decoder}[]
	self.active_sounds = {}

	self.gc_proxy = newproxy(true)
	local mt = getmetatable(self.gc_proxy)
	function mt.__gc()
		if not self.released then
			self:release()
		end
	end
end

function MixerSource:release()
	if self.released then
		return
	end
	self.released = true

	bass_assert(bass.BASS_ChannelFree(self.channel) == 1)

	for _, sound in ipairs(self.active_sounds) do
		sound.decoder:release()
	end
	self.active_sounds = {}
end

---@param decoder rizu.audio.bass.Decoder
---@param volume number?
function MixerSource:addSound(decoder, volume)
	-- Use the resample_channel from Decoder (it's a decoding mixer)
	local source_channel = decoder.resample_channel

	-- BASS_MIXER_NORAMPIN ensures instant start for hitsounds
	---@type integer
	local ok = bass_mix.BASS_Mixer_StreamAddChannel(self.mixer_channel, source_channel, bass_flags.BASS_MIXER_NORAMPIN)
	bass_assert(ok == 1)

	if volume and volume ~= 1 then
		bass.BASS_ChannelSetAttribute(source_channel, bass_flags.BASS_ATTRIB_VOL, volume)
	end

	table.insert(self.active_sounds, {
		decoder = decoder,
	})
end

function MixerSource:update()
	local i = 1
	while i <= #self.active_sounds do
		local sound = self.active_sounds[i]
		local channel = sound.decoder.resample_channel

		---@type integer
		local pos = bass_mix.BASS_Mixer_ChannelGetPosition(channel, bass_flags.BASS_POS_BYTE)
		---@type integer
		local len = bass.BASS_ChannelGetLength(channel, bass_flags.BASS_POS_BYTE)

		-- BASS_ACTIVE_STOPPED = 0
		if (pos >= len and len > 0) or bass_mix.BASS_Mixer_ChannelIsActive(channel) == 0 then
			sound.decoder:release()
			table.remove(self.active_sounds, i)
		else
			i = i + 1
		end
	end
end

function MixerSource:play()
	bass.BASS_ChannelPlay(self.channel, false)
end

function MixerSource:pause()
	bass.BASS_ChannelPause(self.channel)
end

---@param rate number
function MixerSource:setRate(rate)
	if self.use_tempo then
		bass_assert(bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_TEMPO, (rate - 1) * 100) == 1)
	else
		bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_FREQ, self.sample_rate * rate)
	end
end

---@param volume number
function MixerSource:setVolume(volume)
	bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_VOL, volume)
end

return MixerSource
