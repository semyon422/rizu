local ffi = require("ffi")
local bit = require("bit")
local byte = require("byte")
local table_util = require("table_util")

---@class rizu.BinaryEvent
---@field time number
---@field id rizu.VirtualInputEventId
---@field value rizu.VirtualInputEventValue?
---@field column integer? 1-127
---@field pos {[1]: number, [2]: number}?

---@class rizu.BinaryEvents
local BinaryEvents = {}

local u = byte.yield_union()

local value_enum = {
	[false] = 1,
	[true] = 2,
	left = 3,
	right = 4,
}

---@param event rizu.BinaryEvent
local function encode_event(event)
	u.f64 = event.time
	u.u8 = event.id
	u.u8 = value_enum[event.value] or 0

	local column = event.column or 0
	local pos = event.pos

	if not pos then
		u.u8 = column
		return
	end

	u.u8 = bit.bor(column, 0b10000000)
	u.f64 = pos[1]
	u.f64 = pos[2]
end

---@return rizu.BinaryEvent
local function decode_event()
	---@type rizu.BinaryEvent
	local event = {
		time = u.f64,
		id = u.u8,
		value = table_util.keyof(value_enum, u.u8),
	}

	local b = u.u8
	local column = bit.band(b, 0b01111111)
	if column ~= 0 then
		event.column = column
	end

	if bit.band(b, 0b10000000) ~= 0 then
		event.pos = {u.f64, u.f64}
	end

	return event
end

---@param events rizu.BinaryEvent[]
local function encode(events)
	u.u32 = #events
	for _, event in ipairs(events) do
		encode_event(event)
	end
end

---@return rizu.BinaryEvent[]
local function decode()
	local count = u.u32
	---@type rizu.BinaryEvent[]
	local events = {}
	for i = 1, count do
		events[i] = decode_event()
	end
	return events
end

---@param events rizu.BinaryEvent[]
---@return string
function BinaryEvents.encode(events)
	local buf = byte.buffer(8192)
	local f = byte.stretchy_seeker(buf)

	local ok, bytes = byte.apply(f, encode, events)
	if not ok then
		buf:free()
		error("events encoding failed")
	end

	buf:seek(0)
	local s = buf:string(bytes)
	buf:free()

	return s
end

---@param s string
---@return rizu.BinaryEvent[]
function BinaryEvents.decode(s)
	local p, size = ffi.cast("const char *", s), #s

	local ok, bytes, value = byte.apply(byte.seeker(p, size), decode)
	assert(ok, "invalid data")
	return value
end

return BinaryEvents
