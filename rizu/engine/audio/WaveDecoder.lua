local IDecoder = require("rizu.engine.audio.IDecoder")
local ffi = require("ffi")

---@class rizu.audio.WaveDecoder: rizu.audio.IDecoder
---@operator call: rizu.audio.WaveDecoder
local WaveDecoder = IDecoder + {}

---@param data string
function WaveDecoder:new(data)
	local Wave = require("audio.Wave")
	self.wave = Wave()
	self.wave:decode(data)
	self.frame_position = 0
end

---@param buf ffi.cdata*
---@param frame_count integer
---@return integer
function WaveDecoder:getFrames(buf, frame_count)
	local frames = math.min(self.wave.samples_count - self.frame_position, frame_count)
	if frames <= 0 then return 0 end
	local bytes_per_frame = self.wave.channels_count * self.wave.bytes_per_sample
	ffi.copy(buf, self.wave.byte_ptr + self.frame_position * bytes_per_frame, frames * bytes_per_frame)
	self.frame_position = self.frame_position + frames
	return frames
end

function WaveDecoder:getFramePosition() return self.frame_position end
function WaveDecoder:setFramePosition(frame) self.frame_position = frame end
function WaveDecoder:getFrameDuration() return self.wave.samples_count end
function WaveDecoder:getSampleRate() return self.wave.sample_rate end
function WaveDecoder:getChannelCount() return self.wave.channels_count end
function WaveDecoder:getSampleFormat() return "int16" end

return WaveDecoder
