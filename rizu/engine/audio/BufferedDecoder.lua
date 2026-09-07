local IDecoder = require("rizu.engine.audio.IDecoder")
local ffi = require("ffi")

---@class rizu.audio.BufferedDecoder: rizu.audio.IDecoder
---@operator call: rizu.audio.BufferedDecoder
---@field private decoder rizu.audio.IDecoder
---@field private buffer_limit_frames integer
---@field private chunk_frames integer
---@field private chunks {data: ffi.cdata*, frames: integer, frame_pos: integer}[]
---@field private total_buffered_frames integer
---@field private frame_position integer
---@field private eof boolean
---@field private preloader_co thread
---@field private pending_frame integer?
---@field private sample_rate integer
---@field private channels integer
---@field private sample_format rizu.audio.SampleFormat
---@field private duration number
local BufferedDecoder = IDecoder + {}

---@param decoder rizu.audio.IDecoder
---@param buffer_seconds number?
function BufferedDecoder:new(decoder, buffer_seconds)
	self.decoder = decoder
	self.is_preloading = false

	local function load_metadata()
		self.sample_rate = decoder:getSampleRate()
		self.channels = decoder:getChannelCount()
		self.sample_format = decoder:getSampleFormat()
		self.duration = decoder:getDuration()
	end
	local ok = pcall(load_metadata)
	if not ok then
		self.sample_rate = 44100
		self.channels = 2
		self.sample_format = "int16"
		self.duration = 0
	end

	self.buffer_limit_frames = math.floor((buffer_seconds or 1) * self.sample_rate)
	self.chunk_frames = self.buffer_limit_frames
	self.chunks = {}
	self.total_buffered_frames = 0
	local pos_ok, pos = pcall(decoder.getFramePosition, decoder)
	self.frame_position = pos_ok and pos or 0
	self.eof = false
	self.pending_frame = nil

	self.preloader_co = coroutine.create(function()
		while true do
			if self.pending_frame then
				local frame = self.pending_frame
				self.pending_frame = nil
				self.is_preloading = true
				pcall(self.decoder.setFramePosition, self.decoder, frame)
				self.is_preloading = false
			end

			if not self.eof and self.total_buffered_frames < self.buffer_limit_frames then
				local frame_count = math.min(self.chunk_frames, self.buffer_limit_frames - self.total_buffered_frames)
				self.is_preloading = true
				local _ok, data = pcall(self.decoder.getFramesString, self.decoder, frame_count)
				self.is_preloading = false

				if _ok then
					local bytes_per_frame = self.channels * self:getBytesPerSample()
					local frames = #data / bytes_per_frame
					if not self.pending_frame then
						if frames > 0 then
							local buf = ffi.new("int8_t[?]", #data)
							ffi.copy(buf, data, #data)
							table.insert(self.chunks, {data = buf, frames = frames, frame_pos = 0})
							self.total_buffered_frames = self.total_buffered_frames + frames
						else
							self.eof = true
						end
					end
				else
					if tostring(data):find("ThreadRemote reset") then
						return
					end
					coroutine.yield()
				end
			else
				coroutine.yield()
			end
		end
	end)
end

---@param buf ffi.cdata*
---@param frame_count integer
---@return integer
function BufferedDecoder:getFrames(buf, frame_count)
	if not self.is_preloading and coroutine.status(self.preloader_co) == "suspended" then
		local ok, err = coroutine.resume(self.preloader_co)
		if not ok then error(err) end
	end

	local total_frames = 0
	local bytes_per_frame = self.channels * self:getBytesPerSample()
	local dst = ffi.cast("int8_t*", buf)

	while total_frames < frame_count and #self.chunks > 0 do
		local chunk = self.chunks[1]
		---@type integer
		local frames = math.min(frame_count - total_frames, chunk.frames - chunk.frame_pos)
		ffi.copy(dst + total_frames * bytes_per_frame, chunk.data + chunk.frame_pos * bytes_per_frame, frames * bytes_per_frame)

		chunk.frame_pos = chunk.frame_pos + frames
		total_frames = total_frames + frames
		---@diagnostic disable-next-line: no-unknown
		self.total_buffered_frames = self.total_buffered_frames - frames

		if chunk.frame_pos >= chunk.frames then
			table.remove(self.chunks, 1)
		end
	end

	if total_frames == 0 and not self.eof then
		return 0
	end

	self.frame_position = self.frame_position + total_frames
	return total_frames
end

function BufferedDecoder:getSampleRate() return self.sample_rate end
function BufferedDecoder:getChannelCount() return self.channels end
function BufferedDecoder:getSampleFormat() return self.sample_format end
function BufferedDecoder:getDuration() return self.duration end
function BufferedDecoder:getFrameDuration() return math.floor(self.duration * self.sample_rate) end
function BufferedDecoder:getFramePosition() return self.frame_position end

---@param frame integer
function BufferedDecoder:setFramePosition(frame)
	self.pending_frame = frame
	self.chunks = {}
	self.total_buffered_frames = 0
	self.frame_position = frame
	self.eof = false

	if not self.is_preloading and coroutine.status(self.preloader_co) == "suspended" then
		local ok, err = coroutine.resume(self.preloader_co)
		if not ok then error(err) end
	end
end

function BufferedDecoder:release()
	local decoder = self.decoder
	if decoder then
		coroutine.wrap(function()
			pcall(decoder.release, decoder)
		end)()
	end
	self.preloader_co = nil
end

return BufferedDecoder
