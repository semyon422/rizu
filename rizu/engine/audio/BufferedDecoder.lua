local IDecoder = require("rizu.engine.audio.IDecoder")
local ffi = require("ffi")

---@class rizu.audio.BufferedDecoder: rizu.audio.IDecoder
---@operator call: rizu.audio.BufferedDecoder
---@field private decoder rizu.audio.IDecoder
---@field private buffer_limit_seconds number
---@field private buffer_limit_bytes integer
---@field private chunk_size integer
---@field private chunks {data: ffi.cdata*, size: integer, pos: integer}[]
---@field private total_buffered_bytes integer
---@field private position integer
---@field private eof boolean
---@field private preloader_co thread
---@field private pending_position integer?
---@field private sample_rate integer
---@field private channels integer
---@field private bytes_per_sample integer
---@field private duration number
local BufferedDecoder = IDecoder + {}

---@param decoder rizu.audio.IDecoder
---@param buffer_seconds number?
function BufferedDecoder:new(decoder, buffer_seconds)
	self.decoder = decoder
	self.buffer_limit_seconds = buffer_seconds or 1
	self.is_preloading = false

	-- Cache metadata. We assume these are available without yielding or
	-- handle them being called in a coroutine context if necessary.
	local function load_metadata()
		self.sample_rate = decoder:getSampleRate()
		self.channels = decoder:getChannelCount()
		self.bytes_per_sample = decoder:getBytesPerSample()
		self.duration = decoder:getDuration()
	end
	local ok, err = pcall(load_metadata)
	if not ok then
		-- Metadata fetch failed, likely due to reset. 
		-- We still need to initialize fields to avoid errors in bytesToSeconds.
		self.sample_rate = 44100
		self.channels = 2
		self.bytes_per_sample = 2
		self.duration = 0
		-- If it's not a reset, we might want to know, but for previews it's often better to just fail silently or with defaults
	end

	self.buffer_limit_bytes = self:secondsToBytes(self.buffer_limit_seconds)
	-- Thread-remote decoder responses are serviced by the main update loop.
	-- Request a full buffer at once so low frame rates do not limit audio throughput.
	self.chunk_size = self.buffer_limit_bytes

	self.chunks = {}
	self.total_buffered_bytes = 0
	local pos_ok, pos = pcall(decoder.getBytesPosition, decoder)
	self.position = pos_ok and pos or 0
	self.eof = false
	self.pending_position = nil

	self.preloader_co = coroutine.create(function()
		while true do
			-- Handle pending seek
			if self.pending_position then
				local pos = self.pending_position
				self.pending_position = nil
				self.is_preloading = true
				pcall(self.decoder.setBytesPosition, self.decoder, pos)
				self.is_preloading = false
				-- chunks are cleared in setBytesPosition for immediate effect in getData
			end

			-- Fill buffer if not full and not at EOF
			if not self.eof and self.total_buffered_bytes < self.buffer_limit_bytes then
				local read_len = math.min(self.chunk_size, self.buffer_limit_bytes - self.total_buffered_bytes)
				self.is_preloading = true
				local _ok, data = pcall(self.decoder.getDataString, self.decoder, read_len)
				self.is_preloading = false

				if _ok then
					local read = #data

					-- If a seek was requested while we were yielding in getDataString, discard this data
					if not self.pending_position then
						if read > 0 then
							local buf = ffi.new("int8_t[?]", read)
							ffi.copy(buf, data, read)
							table.insert(self.chunks, {data = buf, size = read, pos = 0})
							self.total_buffered_bytes = self.total_buffered_bytes + read
						elseif read == 0 then
							self.eof = true
						end
					end
				else
					-- getDataString failed
					if tostring(data):find("ThreadRemote reset") then
						return -- Terminate preloader cleanly on reset
					end
					-- For other errors, we might want to yield and retry or just terminate
					coroutine.yield()
				end
			else
				-- Buffer full or EOF, wait for more space or a seek
				coroutine.yield()
			end
		end
	end)
end

---@param buf ffi.cdata*
---@param len integer
---@return integer
function BufferedDecoder:getData(buf, len)
	-- Try to advance preloader. We use standard coroutine.resume to NOT
	-- propagate yields from the underlying decoder, keeping this call non-blocking.
	-- We must not resume if it's currently waiting for an ICC response (is_preloading = true).
	if not self.is_preloading and coroutine.status(self.preloader_co) == "suspended" then
		local ok, err = coroutine.resume(self.preloader_co)
		if not ok then
			error(err)
		end
	end

	local total_read = 0
	local dst = ffi.cast("int8_t*", buf)

	-- Consume data from preloaded chunks
	while total_read < len and #self.chunks > 0 do
		local chunk = self.chunks[1]
		local to_copy = math.min(len - total_read, chunk.size - chunk.pos)
		ffi.copy(dst + total_read, chunk.data + chunk.pos, to_copy)

		chunk.pos = chunk.pos + to_copy
		total_read = total_read + to_copy
		self.total_buffered_bytes = self.total_buffered_bytes - to_copy

		if chunk.pos >= chunk.size then
			table.remove(self.chunks, 1)
		end
	end

	if total_read == 0 and not self.eof then
		return 0
	end

	self.position = self.position + total_read
	return total_read
end

function BufferedDecoder:getSampleRate() return self.sample_rate end
function BufferedDecoder:getChannelCount() return self.channels end
function BufferedDecoder:getBytesPerSample() return self.bytes_per_sample end
function BufferedDecoder:getDuration() return self.duration end

function BufferedDecoder:getBytesDuration()
	return self:secondsToBytes(self.duration)
end

function BufferedDecoder:getPosition()
	return self:bytesToSeconds(self.position)
end

function BufferedDecoder:getBytesPosition()
	return self.position
end

---@param pos integer
function BufferedDecoder:setBytesPosition(pos)
	self.pending_position = pos
	self.chunks = {}
	self.total_buffered_bytes = 0
	self.position = pos
	self.eof = false

	-- Resume preloader immediately to process the seek if it was waiting
	-- at the end of the loop. If it's currently preloading (waiting for ICC),
	-- it will handle the pending seek once the current operation finishes.
	if not self.is_preloading and coroutine.status(self.preloader_co) == "suspended" then
		local ok, err = coroutine.resume(self.preloader_co)
		if not ok then
			error(err)
		end
	end
end

---@param pos integer
---@return number
function BufferedDecoder:bytesToSeconds(pos)
	return pos / (self.sample_rate * self.channels * self.bytes_per_sample)
end

---@param pos number
---@return integer
function BufferedDecoder:secondsToBytes(pos)
	return math.floor(pos * self.sample_rate) * self.channels * self.bytes_per_sample
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
