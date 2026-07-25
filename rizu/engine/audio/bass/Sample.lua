local class = require("class")
local ffi = require("ffi")
local bass = require("bass")
local bass_assert = require("bass.assert")
local bass_flags = require("bass.flags")

---@class rizu.audio.bass.Sample
---@operator call: rizu.audio.bass.Sample
local Sample = class()

local sample_info = ffi.new("BASS_SAMPLE[1]")

---@param data string
function Sample:new(data)
	self.sample = bass.BASS_SampleLoad(true, data, 0, #data, 1, 0)
	bass_assert(self.sample ~= 0)

	bass_assert(bass.BASS_SampleGetInfo(self.sample, sample_info) == 1)
	self.sample_rate = sample_info[0].freq

	self.channel = bass.BASS_SampleGetChannel(self.sample, bass_flags.BASS_SAMCHAN_NEW)
	bass_assert(self.channel ~= 0)
end

function Sample:release()
	bass_assert(bass.BASS_SampleFree(self.sample) == 1)
end

function Sample:play()
	bass_assert(bass.BASS_ChannelPlay(self.channel, true) == 1)
end

function Sample:stop()
	bass.BASS_ChannelStop(self.channel)
end

---@param rate number
function Sample:setRate(rate)
	bass_assert(bass.BASS_ChannelSetAttribute(
		self.channel,
		bass_flags.BASS_ATTRIB_FREQ,
		self.sample_rate * rate
	) == 1)
end

---@param volume number
function Sample:setVolume(volume)
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_VOL, volume) == 1)
end

return Sample
