local class = require("class")
local byte = require("byte")
local ffi = require("ffi")

---@class rizu.preview.BgaPreviewEvent
---@field time number
---@field sample_index integer
---@field column integer

---@class rizu.preview.BgaPreview
---@operator call: rizu.preview.BgaPreview
local BgaPreview = class()

function BgaPreview:new()
	---@type string[]
	self.samples = {}
	---@type rizu.preview.BgaPreviewEvent[]
	self.events = {}
end

local u = byte.yield_union()

---@param self rizu.preview.BgaPreview
function BgaPreview._encode_async(self)
	u.char = "BGAP"
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
		u.u16 = event.column
	end
end

---@param self rizu.preview.BgaPreview
function BgaPreview._decode_async(self)
	local magic = u:string(4)
	if magic ~= "BGAP" then
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
		local time = u.f32
		local sample_index = u.u16 + 1
		local column = u.u16
		self.events[i] = {
			time = time,
			sample_index = sample_index,
			column = column,
		}
	end
end

---@return string
function BgaPreview:encode()
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
function BgaPreview:decode(s)
	local ok = byte.apply(byte.seeker(ffi.cast("const char*", s), #s), self._decode_async, self)
	if not ok then
		error("Decoding failed")
	end
end

return BgaPreview
