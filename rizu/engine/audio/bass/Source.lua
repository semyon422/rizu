local ISource = require("rizu.engine.audio.ISource")
local ffi = require("ffi")
local bass = require("bass")
local bass_fx = require("bass.fx")
local bass_assert = require("bass.assert")
local bass_flags = require("bass.flags")
local bass_fft = require("bass.fft")

local fft_flags = {
	[256] = bass_fft.BASS_DATA_FFT256,
	[512] = bass_fft.BASS_DATA_FFT512,
	[1024] = bass_fft.BASS_DATA_FFT1024,
	[2048] = bass_fft.BASS_DATA_FFT2048,
	[4096] = bass_fft.BASS_DATA_FFT4096,
	[8192] = bass_fft.BASS_DATA_FFT8192,
	[16384] = bass_fft.BASS_DATA_FFT16384,
	[32768] = bass_fft.BASS_DATA_FFT32768,
}

---@class rizu.audio.bass.Source: rizu.audio.ISource
---@operator call: rizu.audio.bass.Source
local Source = ISource + {}

---@param decoder rizu.audio.IDecoder
---@param use_tempo boolean?
function Source:new(decoder, use_tempo)
	self.decoder = decoder
	self.use_tempo = use_tempo

	local flags = 0
	if decoder:getBytesPerSample() == 4 then
		flags = flags + bass_flags.BASS_SAMPLE_FLOAT
	end
	if use_tempo then
		flags = flags + bass_flags.BASS_STREAM_DECODE
	end

	---@type integer
	local source_channel = bass.BASS_StreamCreate(decoder:getSampleRate(), decoder:getChannelCount(), flags, ffi.cast("STREAMPROC*", -1), nil)
	self.source_channel = source_channel
	bass_assert(source_channel ~= 0)

	if use_tempo then
		self.channel = bass_fx.BASS_FX_TempoCreate(source_channel, bass_flags.BASS_FX_FREESOURCE)
		bass_assert(self.channel ~= 0)
	else
		self.channel = source_channel
	end

	-- Reduce playback buffer to minimum for lowest latency
	if use_tempo then -- Push streams (using STREAMPROC_PUSH) are also unaffected
		bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_BUFFER, 0)
	end

	self.frame_size = decoder:getChannelCount() * decoder:getBytesPerSample()

	local bytes_per_second = decoder:getSampleRate() * self.frame_size
	self.buf_len = math.floor(bytes_per_second * 0.5)
	self.buf = ffi.new("uint8_t[?]", self.buf_len)

	ffi.gc(self.buf, function()
		self:release()
	end)

	self.pos_offset = 0
end

function Source:release()
	bass_assert(bass.BASS_ChannelFree(self.channel) == 1)
	ffi.gc(self.buf, nil)
end

function Source:play()
	bass_assert(bass.BASS_ChannelPlay(self.channel, false) == 1)
end

function Source:pause()
	bass.BASS_ChannelPause(self.channel)
end

---@return boolean
function Source:isPlaying()
	return bass.BASS_ChannelIsActive(self.channel) == bass_flags.BASS_ACTIVE_PLAYING
end

---@param rate number
function Source:setRate(rate)
	if self.use_tempo then
		bass_assert(bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_TEMPO, (rate - 1) * 100) == 1)
	else
		bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_FREQ, self.decoder:getSampleRate() * rate)
	end
end

---@return number
function Source:getPosition()
	---@type integer
	local pos = bass.BASS_ChannelGetPosition(self.channel, bass_flags.BASS_POS_BYTE)
	bass_assert(pos >= 0)
	---@type number
	pos = bass.BASS_ChannelBytes2Seconds(self.channel, pos)
	bass_assert(pos >= 0)
	return pos + self.pos_offset
end

---@param pos number
function Source:setPosition(pos)
	self.pos_offset = pos

	self.decoder:setPosition(pos)

	---@type integer
	local ok = bass.BASS_ChannelSetPosition(self.channel, 0, 0)
	bass_assert(ok == 1)

	self:update()
end

---@param volume number
function Source:setVolume(volume)
	bass_assert(bass.BASS_ChannelSetAttribute(self.channel, bass_flags.BASS_ATTRIB_VOL, volume) == 1)
end

---@param size integer
function Source:setFFTSize(size)
	local flag = fft_flags[size]
	if not flag then
		error("Invalid FFT size: " .. tostring(size))
	end
	self.fft_flag = flag
	self.fft_buffer = ffi.new("float[?]", size / 2)
end

---@return ffi.cdata*?
function Source:getFFT()
	if not self.fft_buffer then
		return nil
	end
	bass.BASS_ChannelGetData(self.channel, self.fft_buffer, self.fft_flag)
	return self.fft_buffer
end

---@private
function Source:getNeedBytesSource()
	---@type integer
	local available = bass.BASS_ChannelGetData(self.source_channel, nil, bass_flags.BASS_DATA_AVAILABLE)
	return self.buf_len - available
end

---@private
function Source:getNeedBytesTempo()
	---@type integer
	local available_source = bass.BASS_StreamPutData(self.source_channel, nil, 0)

	---@type integer
	-- local available_tempo = bass.BASS_ChannelGetData(self.channel, nil, bass_flags.BASS_DATA_AVAILABLE)

	--- TODO: smooth

	return self.buf_len - available_source
end

function Source:update()
	local need_bytes = 0

	if not self.use_tempo then
		need_bytes = self:getNeedBytesSource()
	else
		need_bytes = self:getNeedBytesTempo()
	end

	if need_bytes <= 0 then
		return
	end

	local read = self.decoder:getData(self.buf, need_bytes)
	if read > 0 then
		---@type integer
		local bytes = bass.BASS_StreamPutData(self.source_channel, self.buf, read)
		bass_assert(bytes ~= -1)
	end
end

return Source
