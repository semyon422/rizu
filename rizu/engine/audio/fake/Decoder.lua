local IDecoder = require("rizu.engine.audio.IDecoder")
local Wave = require("audio.Wave")
local ffi = require("ffi")

---@class rizu.audio.fake.Decoder: rizu.audio.IDecoder
---@operator call: rizu.audio.fake.Decoder
local Decoder = IDecoder + {}

---@param samples_count integer
---@param sample_rate integer?
---@param channels_count integer?
---@param float boolean? If true, decodes float samples (4 bytes each) from the int16 wave
function Decoder:new(samples_count, sample_rate, channels_count, float)
	local wave = Wave()
	self.wave = wave

	wave.sample_rate = sample_rate or wave.sample_rate
	wave:initBuffer(channels_count or 2, assert(samples_count))

	self.float = float or false
	self.position = 0
end

---@param buf ffi.cdata*
---@param len integer
---@return integer
function Decoder:getData(buf, len)
	local wave = self.wave
	if self.float then
		local bps = 4
		local mul = wave.channels_count * bps
		len = math.floor(len / mul) * mul

		local bytes = math.min(wave:getDataSize() * 2 - self.position, len)
		if bytes == 0 then
			return 0
		end

		local samples = bytes / bps
		local src = ffi.cast("int16_t*", wave.byte_ptr + self.position / 2)
		---@type {[integer]: number}
		local dst = ffi.cast("float*", buf)
		for i = 0, samples - 1 do
			dst[i] = src[i] / 32768.0
		end
		self.position = self.position + bytes

		return bytes
	end

	len = wave:floorBytes(len)

	local bytes = math.min(wave:getDataSize() - self.position, len)
	if bytes == 0 then
		return 0
	end

	ffi.copy(buf, wave.byte_ptr + self.position, bytes)
	self.position = self.position + bytes

	return bytes
end

---@param pos integer
---@return number
function Decoder:bytesToSeconds(pos)
	if self.float then
		return self.wave:bytesToSeconds(pos / 2)
	end
	return self.wave:bytesToSeconds(pos)
end

---@param pos number
---@return integer
function Decoder:secondsToBytes(pos)
	if self.float then
		return self.wave:secondsToBytes(pos) * 2
	end
	return self.wave:secondsToBytes(pos)
end

---@return integer
function Decoder:getBytesPosition()
	return self.position
end

---@param pos integer
function Decoder:setBytesPosition(pos)
	self.position = pos
end

---@return integer
function Decoder:getBytesDuration()
	if self.float then
		return self.wave:getDataSize() * 2
	end
	return self.wave:getDataSize()
end

---@return integer
function Decoder:getSampleRate()
	return self.wave.sample_rate
end

---@return integer
function Decoder:getChannelCount()
	return self.wave.channels_count
end

---@return integer
function Decoder:getBytesPerSample()
	if self.float then
		return 4
	end
	return self.wave.bytes_per_sample
end

return Decoder
