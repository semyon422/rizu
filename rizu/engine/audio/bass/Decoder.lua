local IDecoder = require("rizu.engine.audio.IDecoder")
local bit = require("bit")
local ffi = require("ffi")
local bass = require("bass")
local bass_assert = require("bass.assert")
local bass_mix = require("bass.mix")
local bass_flags = require("bass.flags")

---@class rizu.audio.bass.Decoder: rizu.audio.IDecoder
---@operator call: rizu.audio.bass.Decoder
---@field resample_channel integer
local Decoder = IDecoder + {}

Decoder.sample_rate = 44100
Decoder.channels_count = 2

---@param channel integer
---@return integer
local function get_length(channel)
	---@type integer
	local length = bass.BASS_ChannelGetLength(channel, 0)
	bass_assert(length >= 0)
	return tonumber(length) ---@diagnostic disable-line: return-type-mismatch
end

---@param data string
---@return number
function Decoder.probeDuration(data)
	---@type integer
	local channel = bass.BASS_StreamCreateFile(true, data, 0, #data, bit.bor(bass_flags.BASS_STREAM_DECODE, bass_flags.BASS_STREAM_PRESCAN))
	bass_assert(channel ~= 0)

	---@type boolean, number
	local ok, duration = pcall(function()
		local length = get_length(channel)
		---@type number
		local seconds = bass.BASS_ChannelBytes2Seconds(channel, length)
		bass_assert(seconds >= 0)
		return seconds
	end)
	---@diagnostic disable-next-line: no-unknown
	local freed = bass.BASS_StreamFree(channel)
	if not ok then
		error(duration, 0)
	end
	bass_assert(freed == 1)
	return duration
end

---@param data string
---@param sample_format rizu.audio.SampleFormat?
function Decoder:new(data, sample_format)
	self.data = data
	self.sample_format = sample_format or "int16"
	assert(self.sample_format == "int16" or self.sample_format == "float32")

	---@type integer
	self.decode_channel = bass.BASS_StreamCreateFile(true, data, 0, #data, bit.bor(bass_flags.BASS_STREAM_DECODE, bass_flags.BASS_STREAM_PRESCAN))
	bass_assert(self.decode_channel ~= 0)
	local source_length = get_length(self.decode_channel)
	---@type number
	local duration = bass.BASS_ChannelBytes2Seconds(self.decode_channel, source_length)
	bass_assert(duration >= 0)
	self.frame_duration = math.floor(duration * self.sample_rate)

	local flags = bass_flags.BASS_STREAM_DECODE
	if self.sample_format == "float32" then
		flags = flags + bass_flags.BASS_SAMPLE_FLOAT
	end

	---@type integer
	self.resample_channel = bass_mix.BASS_Mixer_StreamCreate(self.sample_rate, self.channels_count, flags)
	bass_assert(self.resample_channel ~= 0)

	---@type integer
	local ok = bass_mix.BASS_Mixer_StreamAddChannel(self.resample_channel, self.decode_channel, bass_flags.BASS_MIXER_CHAN_NORAMPIN)
	bass_assert(ok == 1)

	self.frame_position = 0

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
---@param frame_count integer
---@return integer
function Decoder:getFrames(buf, frame_count)
	local bytes_per_frame = self.channels_count * self:getBytesPerSample()
	---@type integer
	local data_bytes = bass.BASS_ChannelGetData(self.resample_channel, buf, frame_count * bytes_per_frame)
	bass_assert(data_bytes ~= -1)
	local frames = data_bytes / bytes_per_frame
	self.frame_position = self.frame_position + frames
	return frames
end

---@return integer
function Decoder:getFramePosition()
	return self.frame_position
end

---@param frame integer
function Decoder:setFramePosition(frame)
	self.frame_position = frame
	local seconds = frame / self.sample_rate
	---@type integer
	local byte_position = bass.BASS_ChannelSeconds2Bytes(self.decode_channel, seconds)
	bass_assert(byte_position ~= -1)
	---@type integer
	local result = bass_mix.BASS_Mixer_ChannelSetPosition(self.decode_channel, byte_position, bass_flags.BASS_POS_BYTE)
	bass_assert(result >= 0)
end

---@return integer
function Decoder:getFrameDuration()
	return self.frame_duration
end

function Decoder:getSampleRate() return self.sample_rate end
function Decoder:getChannelCount() return self.channels_count end
function Decoder:getSampleFormat() return self.sample_format end

return Decoder
