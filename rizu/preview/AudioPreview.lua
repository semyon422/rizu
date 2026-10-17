local class = require("class")
local byte = require("byte")
local ffi = require("ffi")

---@class rizu.preview.AudioPreviewEvent
---@field time number
---@field sample_index integer
---@field duration number
---@field volume number

---@class rizu.preview.AudioPreview
---@operator call: rizu.preview.AudioPreview
local AudioPreview = class()

function AudioPreview:new()
	---@type string[]
	self.samples = {}
	---@type rizu.preview.AudioPreviewEvent[]
	self.events = {}
end

local u = byte.yield_union()

---@param self rizu.preview.AudioPreview
function AudioPreview._encode_async(self)
	u.char = "AUDP"
	u.u8 = 1 -- version

	u.u16 = #self.samples
	for _, path in ipairs(self.samples) do
		u.u16 = #path
		u.char = path
	end

	u.u32 = #self.events
	for _, event in ipairs(self.events) do
		u.f32 = event.time
		u.u16 = event.sample_index - 1
		u.f32 = event.duration
		u.u8 = math.floor(event.volume * 255 + 0.5)
	end
end

---@param self rizu.preview.AudioPreview
function AudioPreview._decode_async(self)
	local magic = u:string(4)
	if magic ~= "AUDP" then
		error("Invalid magic: " .. tostring(magic))
	end

	local version = u.u8
	if version ~= 1 then
		error("Unsupported version: " .. version)
	end

	local sample_count = u.u16
	self.samples = {}
	for i = 1, sample_count do
		local len = u.u16
		self.samples[i] = u:string(len)
	end

	local event_count = u.u32
	self.events = {}
	for i = 1, event_count do
		self.events[i] = {
			time = u.f32,
			sample_index = u.u16 + 1,
			duration = u.f32,
			volume = u.u8 / 255,
		}
	end
end

---@return string
function AudioPreview:encode()
	local buf = byte.buffer(1024)
	local f = byte.stretchy_seeker(buf)

	local ok, bytes = byte.apply(f, self._encode_async, self)
	if not ok then
		buf:free()
		error("Encoding failed")
	end

	local s = ffi.string(buf.ptr, bytes)
	buf:free()

	return s
end

---@param s string
function AudioPreview:decode(s)
	local ok = byte.apply(byte.seeker(ffi.cast("const char*", s), #s), self._decode_async, self)
	if not ok then
		error("Decoding failed")
	end
end

---@return number, number
function AudioPreview:getRange()
	local min_time = 0
	local max_time = 0

	if #self.events > 0 then
		min_time = self.events[1].time
		max_time = self.events[1].time + self.events[1].duration

		for i = 2, #self.events do
			local event = self.events[i]
			min_time = math.min(min_time, event.time)
			max_time = math.max(max_time, event.time + event.duration)
		end
	end

	return min_time, max_time
end

return AudioPreview
