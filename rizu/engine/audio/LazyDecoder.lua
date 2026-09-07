local IDecoder = require("rizu.engine.audio.IDecoder")
local ffi = require("ffi")

---@class rizu.audio.LazyDecoder: rizu.audio.IDecoder
---@field private fs fs.IFilesystem
---@field private path string
---@field private factory fun(data: string): rizu.audio.IDecoder
---@field private duration number
---@field private sample_rate integer
---@field private channels integer
---@field private sample_format rizu.audio.SampleFormat
---@field private volume number
---@field private real_decoder rizu.audio.IDecoder?
---@field private frame_position integer
local LazyDecoder = IDecoder + {}

---@param fs fs.IFilesystem
---@param path string
---@param factory fun(data: string): rizu.audio.IDecoder
---@param duration number
---@param sample_rate integer
---@param channels integer
---@param sample_format rizu.audio.SampleFormat
---@param volume number?
function LazyDecoder:new(fs, path, factory, duration, sample_rate, channels, sample_format, volume)
	self:init(factory, duration, sample_rate, channels, sample_format, volume)
	self.fs = fs
	self.path = path
end

---@param factory fun(data: string): rizu.audio.IDecoder
---@param duration number
---@param sample_rate integer
---@param channels integer
---@param sample_format rizu.audio.SampleFormat
---@param volume number?
function LazyDecoder:init(factory, duration, sample_rate, channels, sample_format, volume)
	self.factory = factory
	self.duration = duration
	self.sample_rate = sample_rate
	self.channels = channels
	self.sample_format = sample_format
	self.volume = volume or 1
	self.real_decoder = nil
	self.frame_position = 0
end

---@protected
---@return string
function LazyDecoder:loadData()
	return self.fs:read(self.path) or ""
end

---@private
---@return rizu.audio.IDecoder
function LazyDecoder:ensureLoaded()
	if not self.real_decoder then
		local data = self:loadData()
		self.real_decoder = self.factory(data)
		assert(self.real_decoder:getSampleRate() == self.sample_rate)
		assert(self.real_decoder:getChannelCount() == self.channels)
		assert(self.real_decoder:getSampleFormat() == self.sample_format)
		if self.frame_position ~= 0 then
			self.real_decoder:setFramePosition(self.frame_position)
		end
	end
	return self.real_decoder
end

---@param buf ffi.cdata*
---@param frame_count integer
---@return integer
function LazyDecoder:getFrames(buf, frame_count)
	local dec = self:ensureLoaded()
	local frames = dec:getFrames(buf, frame_count)

	if self.volume ~= 1 and frames > 0 then
		local sample_count = frames * self.channels
		local vol = self.volume
		if self.sample_format == "float32" then
			---@type {[integer]: number}
			local ptr = ffi.cast("float*", buf)
			for i = 0, sample_count - 1 do
				ptr[i] = ptr[i] * vol
			end
		else
			---@type {[integer]: integer}
			local ptr = ffi.cast("int16_t*", buf)
			for i = 0, sample_count - 1 do
				local val = math.floor(ptr[i] * vol + 0.5)
				ptr[i] = math.min(math.max(val, -32768), 32767)
			end
		end
	end

	return frames
end

function LazyDecoder:getSampleRate() return self.sample_rate end
function LazyDecoder:getChannelCount() return self.channels end
function LazyDecoder:getSampleFormat() return self.sample_format end
function LazyDecoder:getDuration() return self.duration end

function LazyDecoder:getFrameDuration()
	return math.floor(self.duration * self.sample_rate)
end

function LazyDecoder:getFramePosition()
	if self.real_decoder then
		return self.real_decoder:getFramePosition()
	end
	return self.frame_position
end

function LazyDecoder:setFramePosition(frame)
	if self.real_decoder then
		self.real_decoder:setFramePosition(frame)
	else
		self.frame_position = frame
	end
end

function LazyDecoder:release()
	if self.real_decoder then
		self.real_decoder:release()
		self.real_decoder = nil
	end
end

return LazyDecoder
