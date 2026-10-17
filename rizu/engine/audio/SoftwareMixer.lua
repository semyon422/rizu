local class = require("class")
local IDecoder = require("rizu.engine.audio.IDecoder")
local FakeDecoder = require("rizu.engine.audio.fake.Decoder")
local rbtree = require("rbtree")
local ffi = require("ffi")

local next_entry_id = 1

---@class rizu.audio.SoftwareMixer.NodeWrap
---@operator call: rizu.audio.SoftwareMixer.NodeWrap
---@field entry rizu.audio.SoftwareMixer.Entry
---@field is_search_key boolean?
local NodeWrap = class()

---@param entry rizu.audio.SoftwareMixer.Entry
---@param is_search_key boolean?
function NodeWrap:new(entry, is_search_key)
	self.entry = entry
	self.is_search_key = is_search_key
end

function NodeWrap:tie_breaker(other)
	if self == other then return false end
	if self.is_search_key ~= other.is_search_key then
		-- Search keys are considered "smaller" than real entries at the same pos
		-- to ensure lower_bound finds the first entry.
		return self.is_search_key
	end
	if self.is_search_key then
		-- Tie-breaker for two different search keys at the same pos
		return tostring(self) < tostring(other)
	end
	-- Tie-breaker for two different real entries at the same pos
	return self.entry.id < other.entry.id
end

---@class rizu.audio.SoftwareMixer.StartNodeWrap: rizu.audio.SoftwareMixer.NodeWrap
---@operator call: rizu.audio.SoftwareMixer.StartNodeWrap
local StartNodeWrap = NodeWrap + {}

function StartNodeWrap:__lt(other)
	if self.entry.start_frame ~= other.entry.start_frame then
		return self.entry.start_frame < other.entry.start_frame
	end
	return self:tie_breaker(other)
end

---@class rizu.audio.SoftwareMixer.EndNodeWrap: rizu.audio.SoftwareMixer.NodeWrap
---@operator call: rizu.audio.SoftwareMixer.EndNodeWrap
local EndNodeWrap = NodeWrap + {}

function EndNodeWrap:__lt(other)
	if self.entry.end_frame ~= other.entry.end_frame then
		return self.entry.end_frame < other.entry.end_frame
	end
	return self:tie_breaker(other)
end

---@class rizu.audio.SoftwareMixer.Entry
---@operator call: rizu.audio.SoftwareMixer.Entry
---@field id integer
---@field decoder rizu.audio.IDecoder
---@field time number
---@field duration number
---@field start_frame integer
---@field end_frame integer
---@field start_wrap rizu.audio.SoftwareMixer.StartNodeWrap
---@field end_wrap rizu.audio.SoftwareMixer.EndNodeWrap
local Entry = class()

---@param decoder rizu.audio.IDecoder
---@param time number
function Entry:new(decoder, time)
	self.decoder = decoder
	self.time = time
	self.duration = decoder:getDuration()
	self.start_frame = math.floor(time * decoder:getSampleRate())
	self.end_frame = self.start_frame + decoder:getFrameDuration()

	self.id = next_entry_id
	next_entry_id = next_entry_id + 1

	self.start_wrap = StartNodeWrap(self)
	self.end_wrap = EndNodeWrap(self)
end

---@class rizu.audio.SoftwareMixer: rizu.audio.IDecoder
---@operator call: rizu.audio.SoftwareMixer
local SoftwareMixer = IDecoder + {}

---@param sounds rizu.ChartAudioSound[]
---@param decoders {[integer]: rizu.audio.IDecoder}
---@param output_format rizu.audio.SampleFormat?
function SoftwareMixer:new(sounds, decoders, output_format)
	self.tree_start = rbtree.new()
	self.tree_end = rbtree.new()
	---@type {[rizu.audio.IDecoder]: rizu.audio.SoftwareMixer.Entry}
	self.decoder_to_entry = {}

	self.start_frame = math.huge
	self.end_frame = -math.huge
	self.max_duration_frames = 0

	self.frame_position = 0
	self.output_format = output_format or "int16"
	assert(self.output_format == "int16" or self.output_format == "float32")
	---@type {[rizu.audio.SoftwareMixer.Entry]: boolean}
	self.active_sounds = {}
	self.next_to_add = nil
	self.next_to_remove = nil

	self.dec_buf_len = 0
	self.dec_buf = nil
	self.mix_buf = nil

	self.sample_rate = 44100
	self.channels = 2
	self.sample_format = "int16"

	for i, sound in ipairs(sounds) do
		self:addSound(sound, decoders[i])
	end

	if self.tree_start.size == 0 then
		self.empty = true
		self.start_frame = 0
		self.end_frame = 0
		self.dummy_decoder = FakeDecoder(1, 44100, 2)
	end

	self.frame_position = self.start_frame
	self:resetActiveSet()
end

---@param tree rbtree.Tree
---@param key rizu.audio.SoftwareMixer.NodeWrap
---@return rbtree.Node?
local function find_lower_bound(tree, key)
	---@type rbtree.Node?
	local x = tree.root
	---@type rbtree.Node?
	local res
	while x do
		if not (x.key < key) then
			res = x
			-- LuaLS 3.19 loses the optional node type on branch reassignment.
			---@diagnostic disable-next-line: no-unknown
			x = x.left
		else
			x = x.right
		end
	end
	return res
end

---@private
function SoftwareMixer:resetActiveSet()
	self.active_sounds = {}
	local pos = self.frame_position

	-- Pointers for incremental updates
	local search_start = StartNodeWrap({start_frame = pos}, true)
	self.next_to_add = find_lower_bound(self.tree_start, search_start)

	local search_end = EndNodeWrap({end_frame = pos}, true)
	self.next_to_remove = find_lower_bound(self.tree_end, search_end)

	-- Initial active set: sounds that started before pos and end at or after pos
	if not self.empty then
		local search_seek = StartNodeWrap({start_frame = pos - self.max_duration_frames}, true)
		local node = find_lower_bound(self.tree_start, search_seek) or self.tree_start:min()
		while node and (node.key --[[@as rizu.audio.SoftwareMixer.NodeWrap]]).entry.start_frame < pos do
			local entry = (node.key --[[@as rizu.audio.SoftwareMixer.NodeWrap]]).entry
			if entry.end_frame >= pos then
				self.active_sounds[entry] = true
			end
			-- LuaLS 3.19 loses the optional node type on loop reassignment.
			---@diagnostic disable-next-line: no-unknown
			node = node:next()
		end
	end
end

---@param sound rizu.ChartAudioSound
---@param decoder rizu.audio.IDecoder?
function SoftwareMixer:addSound(sound, decoder)
	if not decoder then
		return
	end

	if self.empty or self.tree_start.size == 0 then
		self.sample_rate = decoder:getSampleRate()
		self.channels = decoder:getChannelCount()
		self.sample_format = decoder:getSampleFormat()
		self.empty = false
		self.start_frame = math.huge
		self.end_frame = -math.huge
		self.max_duration_frames = 0
		if self.dummy_decoder then
			self.dummy_decoder:release()
			self.dummy_decoder = nil
		end
	else
		assert(decoder:getSampleRate() == self.sample_rate, "Decoder sample rate must match mixer format")
		assert(decoder:getChannelCount() == self.channels, "Decoder channel count must match mixer format")
		assert(decoder:getSampleFormat() == self.sample_format, "Decoder sample format must match mixer format")
	end

	assert(self.sample_format == "int16", "SoftwareMixer only accepts int16 decoders")

	local entry = Entry(decoder, sound.time)
	self.decoder_to_entry[decoder] = entry

	self.tree_start:insert(entry.start_wrap)
	self.tree_end:insert(entry.end_wrap)

	self.start_frame = math.min(self.start_frame, entry.start_frame)
	self.end_frame = math.max(self.end_frame, entry.end_frame)
	self.max_duration_frames = math.max(self.max_duration_frames, entry.end_frame - entry.start_frame)

	self:resetActiveSet()
end

---@param decoder rizu.audio.IDecoder
function SoftwareMixer:removeSound(decoder)
	local entry = self.decoder_to_entry[decoder]
	if not entry then
		return
	end

	self.tree_start:remove(entry.start_wrap)
	self.tree_end:remove(entry.end_wrap)

	self.decoder_to_entry[decoder] = nil

	if entry.start_frame == self.start_frame or entry.end_frame == self.end_frame or (entry.end_frame - entry.start_frame) == self.max_duration_frames then
		self:recalculateBounds()
	end

	if self.tree_start.size == 0 then
		self.empty = true
		self.start_frame = 0
		self.end_frame = 0
		self.max_duration_frames = 0
		self.dummy_decoder = FakeDecoder(1, 44100, 2)
	end

	self:resetActiveSet()
end

function SoftwareMixer:recalculateBounds()
	self.start_frame = math.huge
	self.end_frame = -math.huge
	self.max_duration_frames = 0

	for _, key in self.tree_start:iter() do
		local entry = (key --[[@as rizu.audio.SoftwareMixer.NodeWrap]]).entry
		self.start_frame = math.min(self.start_frame, entry.start_frame)
		self.end_frame = math.max(self.end_frame, entry.end_frame)
		self.max_duration_frames = math.max(self.max_duration_frames, entry.end_frame - entry.start_frame)
	end

	if self.tree_start.size == 0 then
		self.start_frame = 0
		self.end_frame = 0
	end
end

---@return number
---@return number
function SoftwareMixer:getTimeBounds()
	return self.start_frame / self.sample_rate, self.end_frame / self.sample_rate
end

function SoftwareMixer:release()
	for _, entry in pairs(self.decoder_to_entry) do
		entry.decoder:release()
	end
	if self.dummy_decoder then
		self.dummy_decoder:release()
	end
end

---@param dst {[integer]: number}
---@param src {[integer]: integer}
---@param size integer
local function add_buffer_float(dst, src, size)
	---@type {[integer]: integer}
	local src_ptr = ffi.cast("int16_t*", src)

	for i = 0, size - 1 do
		dst[i] = dst[i] + src_ptr[i] / 32768
	end
end

---@param dst {[integer]: integer}
---@param src {[integer]: number}
---@param size integer
local function apply_mix(dst, src, size)
	---@type {[integer]: integer}
	local dst_ptr = ffi.cast("int16_t*", dst)

	for i = 0, size - 1 do
		local val = src[i] * 32768
		if val > 32767 then
			dst_ptr[i] = 32767
		elseif val < -32768 then
			dst_ptr[i] = -32768
		else
			dst_ptr[i] = val
		end
	end
end

---@param buf ffi.cdata*
---@param frame_count integer
---@return integer
function SoftwareMixer:getFrames(buf, frame_count)
	frame_count = math.max(math.floor(frame_count), 0)

	if self.empty then
		ffi.fill(buf, frame_count * self.channels * self:getBytesPerSample(), 0)
		self.frame_position = self.frame_position + frame_count
		return frame_count
	end

	local samples = frame_count * self.channels
	local int16_bytes = samples * 2

	if self.dec_buf_len < int16_bytes then
		self.dec_buf_len = int16_bytes
		self.dec_buf = ffi.new("int16_t[?]", samples)
		self.mix_buf = ffi.new("float[?]", samples)
	end

	local dec_buf = self.dec_buf
	local mix_buf = self.mix_buf

	ffi.fill(mix_buf, samples * 4, 0)

	local pos = self.frame_position

	-- 1. Remove sounds that ended before the current buffer
	while self.next_to_remove and self.next_to_remove.key.entry.end_frame < pos do
		self.active_sounds[self.next_to_remove.key.entry] = nil
		self.next_to_remove = self.next_to_remove:next()
	end

	-- 2. Add sounds that start before the end of the current buffer
	while self.next_to_add and self.next_to_add.key.entry.start_frame < pos + frame_count do
		self.active_sounds[self.next_to_add.key.entry] = true
		self.next_to_add = self.next_to_add:next()
	end

	-- 3. Mix all active sounds
	for entry in pairs(self.active_sounds) do
		local start_frame = entry.start_frame
		local end_frame = entry.end_frame

		if end_frame < pos then
			self.active_sounds[entry] = nil
		else
			local need_frames = math.min(pos + frame_count, end_frame) - math.max(pos, start_frame)
			local offset_samples = math.max(start_frame - pos, 0) * self.channels

			if need_frames > 0 then
				local sound_frame = math.max(pos - start_frame, 0)
				if sound_frame ~= entry.decoder:getFramePosition() then
					entry.decoder:setFramePosition(sound_frame)
				end

				local frames = entry.decoder:getFrames(dec_buf, need_frames)
				add_buffer_float(mix_buf + offset_samples, dec_buf, frames * self.channels)
			end
		end
	end

	if self.output_format == "float32" then
		ffi.copy(buf, mix_buf, samples * 4)
	else
		apply_mix(buf, mix_buf, samples)
	end

	self.frame_position = self.frame_position + frame_count
	return frame_count
end

---@return number
function SoftwareMixer:getPosition()
	return self.frame_position / self.sample_rate
end

---@return integer
function SoftwareMixer:getFramePosition()
	return self.frame_position
end

---@param pos number
function SoftwareMixer:setPosition(pos)
	self:setFramePosition(math.floor(pos * self.sample_rate))
end

---@param frame integer
function SoftwareMixer:setFramePosition(frame)
	if frame ~= self.frame_position then
		self.frame_position = frame
		self:resetActiveSet()
	end
end

---@return integer
function SoftwareMixer:getFrameDuration()
	return self.end_frame - self.start_frame
end

---@return integer
function SoftwareMixer:getSamplesDuration()
	return self:getFrameDuration()
end

function SoftwareMixer:getSampleRate() return self.sample_rate end
function SoftwareMixer:getChannelCount() return self.channels end

---@return rizu.audio.SampleFormat
function SoftwareMixer:getSampleFormat()
	return self.output_format
end

return SoftwareMixer
