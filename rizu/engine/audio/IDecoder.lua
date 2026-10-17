local class = require("class")
local ffi = require("ffi")

---@alias rizu.audio.SampleFormat "int16"|"float32"

---@class rizu.audio.IDecoder
---@operator call: rizu.audio.IDecoder
local IDecoder = class()

---@param buf ffi.cdata*
---@param frame_count integer
---@return integer frames_read
function IDecoder:getFrames(buf, frame_count)
	error("not implemented")
end

---@param frame_count integer
---@return string
function IDecoder:getFramesString(frame_count)
	local bytes_per_frame = self:getChannelCount() * self:getBytesPerSample()
	local buf = ffi.new("int8_t[?]", frame_count * bytes_per_frame)
	local frames_read = self:getFrames(buf, frame_count)
	return ffi.string(buf, frames_read * bytes_per_frame)
end

---@return number
function IDecoder:getPosition()
	return self:getFramePosition() / self:getSampleRate()
end

---@return integer
function IDecoder:getFramePosition()
	error("not implemented")
end

---@param pos number
function IDecoder:setPosition(pos)
	self:setFramePosition(math.floor(pos * self:getSampleRate()))
end

---@param frame integer
function IDecoder:setFramePosition(frame)
	error("not implemented")
end

---@return number
function IDecoder:getDuration()
	return self:getFrameDuration() / self:getSampleRate()
end

---@return integer
function IDecoder:getFrameDuration()
	error("not implemented")
end

---@return integer
function IDecoder:getSampleRate()
	error("not implemented")
end

---@return integer
function IDecoder:getChannelCount()
	error("not implemented")
end

---@return rizu.audio.SampleFormat
function IDecoder:getSampleFormat()
	error("not implemented")
end

---@return integer
function IDecoder:getBytesPerSample()
	return self:getSampleFormat() == "float32" and 4 or 2
end

-- Compatibility helpers for byte-oriented consumers. Decoder state is frame-based.
---@param buf ffi.cdata*
---@param byte_count integer
---@return integer bytes_read
function IDecoder:getData(buf, byte_count)
	local bytes_per_frame = self:getChannelCount() * self:getBytesPerSample()
	local frames = self:getFrames(buf, math.floor(byte_count / bytes_per_frame))
	return frames * bytes_per_frame
end

---@param byte_count integer
---@return string
function IDecoder:getDataString(byte_count)
	local bytes_per_frame = self:getChannelCount() * self:getBytesPerSample()
	return self:getFramesString(math.floor(byte_count / bytes_per_frame))
end

function IDecoder:getBytesPosition()
	return self:getFramePosition() * self:getChannelCount() * self:getBytesPerSample()
end

function IDecoder:setBytesPosition(byte_position)
	local bytes_per_frame = self:getChannelCount() * self:getBytesPerSample()
	self:setFramePosition(math.floor(byte_position / bytes_per_frame))
end

function IDecoder:getBytesDuration()
	return self:getFrameDuration() * self:getChannelCount() * self:getBytesPerSample()
end

function IDecoder:bytesToSeconds(byte_position)
	local bytes_per_frame = self:getChannelCount() * self:getBytesPerSample()
	return byte_position / bytes_per_frame / self:getSampleRate()
end

function IDecoder:secondsToBytes(seconds)
	return math.floor(seconds * self:getSampleRate()) * self:getChannelCount() * self:getBytesPerSample()
end

function IDecoder:release() end

return IDecoder
