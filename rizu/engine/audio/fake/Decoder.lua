local IDecoder = require("rizu.engine.audio.IDecoder")
local Wave = require("audio.Wave")
local ffi = require("ffi")

---@class rizu.audio.fake.Decoder: rizu.audio.IDecoder
---@operator call: rizu.audio.fake.Decoder
local Decoder = IDecoder + {}

---@param samples_count integer
---@param sample_rate integer?
---@param channels_count integer?
---@param sample_format rizu.audio.SampleFormat?
function Decoder:new(samples_count, sample_rate, channels_count, sample_format)
	local wave = Wave()
	self.wave = wave

	wave.sample_rate = sample_rate or wave.sample_rate
	wave:initBuffer(channels_count or 2, assert(samples_count))

	self.sample_format = sample_format or "int16"
	self.frame_position = 0
end

---@param buf ffi.cdata*
---@param frame_count integer
---@return integer
function Decoder:getFrames(buf, frame_count)
	local wave = self.wave
	local frames = math.min(wave.samples_count - self.frame_position, math.max(frame_count, 0))
	if frames == 0 then
		return 0
	end

	local channels = wave.channels_count
	local sample_count = frames * channels
	local src = wave.data_buf + self.frame_position * channels
	if self.sample_format == "float32" then
		---@type {[integer]: number}
		local dst = ffi.cast("float*", buf)
		for i = 0, sample_count - 1 do
			dst[i] = src[i] / 32768
		end
	else
		ffi.copy(buf, src, sample_count * 2)
	end
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
end

---@return integer
function Decoder:getFrameDuration()
	return self.wave.samples_count
end

function Decoder:getSampleRate() return self.wave.sample_rate end
function Decoder:getChannelCount() return self.wave.channels_count end
function Decoder:getSampleFormat() return self.sample_format end
function Decoder:release() end

return Decoder
