local ffi = require("ffi")
local bass = require("bass")
local bass_assert = require("bass.assert")
local bass_flags = require("bass.flags")
local bass_mix = require("bass.mix")
local IOutput = require("rizu.engine.audio.IOutput")
local Native = require("rizu.engine.audio.sdl.Native")
local OutputConfig = require("rizu.engine.audio.OutputConfig")

---@class rizu.audio.sdl.MixSource
---@field channel integer

---@class rizu.audio.sdl.Output: rizu.audio.IOutput
---@operator call: rizu.audio.sdl.Output
local Output = IOutput + {}

---@param sources rizu.audio.ISource[]
---@param config rizu.audio.OutputConfigData
function Output:new(sources, config)
	self.sample_rate = 44100
	self.channels = 2
	self.frame_size = self.channels * ffi.sizeof("float")
	self.stream = Native.open(self.sample_rate, self.channels)

	local flags = bass_flags.BASS_STREAM_DECODE + bass_flags.BASS_SAMPLE_FLOAT + bass_flags.BASS_MIXER_NONSTOP
	self.mixer_channel = bass_mix.BASS_Mixer_StreamCreate(self.sample_rate, self.channels, flags)
	bass_assert(self.mixer_channel ~= 0)
	for _, source in ipairs(sources) do
		local mix_source = source --[[@as rizu.audio.sdl.MixSource]]
		if mix_source.channel then
			local ok = bass_mix.BASS_Mixer_StreamAddChannel(
				self.mixer_channel,
				mix_source.channel,
				bass_flags.BASS_MIXER_NORAMPIN
			)
			bass_assert(ok == 1)
		end
	end

	local total_frames = math.floor(config.buffer / 1000 * self.sample_rate + 0.5)
	local requested_frames = total_frames - self.stream.device.sample_frames
	self.target_frames = math.max(requested_frames, self.stream.device.sample_frames)
	self.target_bytes = self.target_frames * self.frame_size
	self.buffer = ffi.new("uint8_t[?]", self.target_bytes)
	self.playing = false
	self.started = false
	self.was_empty = true
	self.underruns = 0
	self.released = false
	self:updateRuntimeStatus(0)

	self.gc_proxy = newproxy(true)
	local mt = getmetatable(self.gc_proxy)
	function mt.__gc()
		if not self.released then
			self:release()
		end
	end
end

---@private
---@param queued_bytes integer
function Output:updateRuntimeStatus(queued_bytes)
	OutputConfig.setRuntimeStatus({
		queued_ms = queued_bytes / self.frame_size / self.sample_rate * 1000,
		target_queue_ms = self.target_frames / self.sample_rate * 1000,
		period_ms = self.stream.device.sample_frames / self.sample_rate * 1000,
		underruns = self.underruns,
	})
end

function Output:release()
	if self.released then
		return
	end
	self.released = true
	self:updateRuntimeStatus(0)
	Native.close(self.stream)
	bass_assert(bass.BASS_ChannelFree(self.mixer_channel) == 1)
end

function Output:play()
	if self.playing then
		return
	end
	self.playing = true
	self:update()
	Native.play(self.stream)
	self.started = true
end

function Output:pause()
	if not self.playing then
		return
	end
	self.playing = false
	Native.pause(self.stream)
end

function Output:clear()
	Native.clear(self.stream)
	self.was_empty = true
	self:updateRuntimeStatus(0)
end

function Output:update()
	if not self.playing then
		return
	end
	local queued = Native.getQueued(self.stream)
	local empty = queued == 0
	if self.started and empty and not self.was_empty then
		self.underruns = self.underruns + 1
	end
	self.was_empty = empty

	local need_bytes = self.target_bytes - queued
	need_bytes = math.floor(need_bytes / self.frame_size) * self.frame_size
	if need_bytes > 0 then
		---@type integer
		local decoded = bass.BASS_ChannelGetData(self.mixer_channel, self.buffer, need_bytes)
		bass_assert(decoded ~= 0xFFFFFFFF)
		if decoded > 0 then
			Native.put(self.stream, self.buffer, decoded)
			queued = queued + decoded
			self.was_empty = false
		end
	end
	self:updateRuntimeStatus(queued)
end

---@param decoded_position number
---@return number audible_position
function Output:getPosition(decoded_position)
	local queued_frames = Native.getQueued(self.stream) / self.frame_size
	local device_frames = self.stream.device.sample_frames
	return decoded_position - (queued_frames + device_frames) / self.sample_rate
end

return Output
