local IDecoder = require("rizu.engine.audio.IDecoder")
local bit = require("bit")
local bass = require("bass")
local bass_assert = require("bass.assert")
local bass_mix = require("bass.mix")
local bass_flags = require("bass.flags")

---@class rizu.audio.bass.Decoder: rizu.audio.IDecoder
---@operator call: rizu.audio.bass.Decoder
local Decoder = IDecoder + {}

Decoder.sample_rate = 44100
Decoder.channels_count = 2
Decoder.bytes_per_sample = 2

---@param channel integer
---@return integer
local function get_length(channel)
	---@type integer
	local length = bass.BASS_ChannelGetLength(channel, 0)
	bass_assert(length >= 0)
	return tonumber(length) ---@diagnostic disable-line: return-type-mismatch
end

---@param data string
function Decoder:new(data)
	self.data = data

	---@type integer
	self.decode_channel = bass.BASS_StreamCreateFile(true, data, 0, #data, bit.bor(bass_flags.BASS_STREAM_DECODE, bass_flags.BASS_STREAM_PRESCAN))
	bass_assert(self.decode_channel ~= 0)
	self.length = get_length(self.decode_channel)

	---@type integer
	self.resample_channel = bass_mix.BASS_Mixer_StreamCreate(self.sample_rate, self.channels_count, bass_flags.BASS_STREAM_DECODE)
	bass_assert(self.resample_channel ~= 0)

	---@type integer
	local ok = bass_mix.BASS_Mixer_StreamAddChannel(self.resample_channel, self.decode_channel, bass_flags.BASS_MIXER_CHAN_NORAMPIN)
	bass_assert(ok == 1)

	self.position = 0
	self.resample_offset = 0

	self.gc_proxy = newproxy(true)
	local mt = getmetatable(self.gc_proxy)
	function mt.__gc()
		if not self.released then
			self:release()
		end
	end
end

function Decoder:release()
	if self.released then
		return
	end
	self.released = true
	bass_assert(bass.BASS_StreamFree(self.resample_channel) == 1)
	bass_assert(bass.BASS_StreamFree(self.decode_channel) == 1)
end

---@param buf ffi.cdata*
---@param len integer
---@return integer
function Decoder:getData(buf, len)
	---@type integer
	local data_bytes = bass.BASS_ChannelGetData(self.resample_channel, buf, len)
	bass_assert(data_bytes ~= -1)
	self.position = self.position + data_bytes
	return data_bytes
end

---@param pos integer
---@return number
function Decoder:bytesToSeconds(pos)
	---@type number
	pos = bass.BASS_ChannelBytes2Seconds(self.resample_channel, pos)
	bass_assert(pos >= 0)
	return pos
end

---@param pos number
---@return integer
function Decoder:secondsToBytes(pos)
	---@type integer
	pos = bass.BASS_ChannelSeconds2Bytes(self.resample_channel, pos)
	bass_assert(pos ~= -1)
	return tonumber(pos) ---@diagnostic disable-line: return-type-mismatch
end

---@return integer
function Decoder:getBytesPosition()
	return self.position
end

---@param pos integer
function Decoder:setBytesPosition(pos)
	self.position = pos
	---@type integer
	pos = bass_mix.BASS_Mixer_ChannelSetPosition(self.decode_channel, pos, bass_flags.BASS_POS_BYTE)
	bass_assert(pos >= 0)
end

---@return integer
function Decoder:getBytesDuration()
	return self.length
end

---@return integer
function Decoder:getSampleRate()
	return self.sample_rate
end

---@return integer
function Decoder:getChannelCount()
	return self.channels_count
end

---@return integer
function Decoder:getBytesPerSample()
	return self.bytes_per_sample
end

return Decoder
