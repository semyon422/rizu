local bit = require("bit")
local ffi = require("ffi")
local byte_mod = require("byte")
local leb128 = require("leb128")

local strbyte = string.byte
local strchar = string.char

--- Binary read/write helpers for Bancho protocol.
---@class bancho.protocol.Binary
local M = {}

--- Write an unsigned LEB128 value.
---@param num integer
---@return string
function M.writeULEB128(num)
	local p = ffi.new("uint8_t[?]", 16)
	local size = leb128.uenc(p, num)
	return ffi.string(p, size)
end

--- Read an unsigned LEB128 value.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readULEB128(buf, offset)
	local p = ffi.cast("const unsigned char*", buf:sub(offset, offset + 15))
	local size, value = leb128.udec(p)
	return tonumber(value), offset + size
end

--- Write a null-terminated or length-prefixed string.
---@param s string
---@return string
function M.writeString(s)
	if #s == 0 then
		return "\000"
	end
	return "\011" .. M.writeULEB128(#s) .. s
end

--- Read a null-terminated or length-prefixed string.
---@param buf string
---@param offset integer
---@return string value
---@return integer next_offset
function M.readString(buf, offset)
	local exists = strbyte(buf, offset) == 0x0B
	local i = offset + 1

	if not exists then
		return "", i
	end

	local len, nextI = M.readULEB128(buf, i)
	i = nextI

	local val = buf:sub(i, i + len - 1)
	return val, i + len
end

--- Write a signed 8-bit integer.
---@param v integer
---@return string
function M.writeI8(v)
	v = tonumber(v) or 0
	return strchar(bit.band(v + 256, 255))
end

--- Write an unsigned 8-bit integer.
---@param v integer
---@return string
function M.writeU8(v)
	v = tonumber(v) or 0
	return strchar(bit.band(v, 255))
end

--- Write a signed 16-bit integer.
---@param v integer
---@return string
function M.writeI16(v)
	v = tonumber(v) or 0
	v = bit.band(v + 65536, 65535)
	return strchar(bit.band(v, 255), bit.rshift(v, 8))
end

--- Write an unsigned 16-bit integer.
---@param v integer
---@return string
function M.writeU16(v)
	v = tonumber(v) or 0
	v = bit.band(v, 65535)
	return strchar(bit.band(v, 255), bit.rshift(v, 8))
end

--- Write a signed 32-bit integer.
---@param v integer
---@return string
function M.writeI32(v)
	v = (tonumber(v) or 0) % 4294967296
	return strchar(
		bit.band(v, 255),
		bit.band(bit.rshift(v, 8), 255),
		bit.band(bit.rshift(v, 16), 255),
		bit.band(bit.rshift(v, 24), 255)
	)
end

--- Write an unsigned 32-bit integer.
---@param v integer
---@return string
function M.writeU32(v)
	return M.writeI32(v)
end

--- Write a signed 64-bit integer.
---@param v integer
---@return string
function M.writeI64(v)
	v = (tonumber(v) or 0) % math.pow(2, 64)
	---@type integer[]
	local out = {}
	for _ = 1, 8 do
		table.insert(out, bit.band(v, 255))
		v = math.floor(v / 256)
	end
	return strchar(out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8])
end

--- Write an unsigned 64-bit integer.
---@param v integer
---@return string
function M.writeU64(v)
	return M.writeI64(v)
end

--- Write a 32-bit float.
---@param v number
---@return string
function M.writeF32(v)
	local p = ffi.new("uint8_t[4]")
	local u = byte_mod.union_le(p)
	u.f32 = tonumber(v) or 0
	return ffi.string(p, 4)
end

--- Write a 64-bit float.
---@param v number
---@return string
function M.writeF64(v)
	local p = ffi.new("uint8_t[8]")
	local u = byte_mod.union_le(p)
	u.f64 = v
	return ffi.string(p, 8)
end

--- Read a signed 8-bit integer.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readI8(buf, offset)
	local b = strbyte(buf, offset)
	return (b > 127 and b - 256 or b), offset + 1
end

--- Read an unsigned 8-bit integer.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readU8(buf, offset)
	return strbyte(buf, offset), offset + 1
end

--- Read a signed 16-bit integer.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readI16(buf, offset)
	local a = strbyte(buf, offset)
	local b = strbyte(buf, offset + 1)
	local v = a + b * 256
	if v >= 32768 then v = v - 65536 end
	return v, offset + 2
end

--- Read an unsigned 16-bit integer.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readU16(buf, offset)
	local a = strbyte(buf, offset)
	local b = strbyte(buf, offset + 1)
	return a + b * 256, offset + 2
end

--- Read a signed 32-bit integer.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readI32(buf, offset)
	local a = strbyte(buf, offset)
	local b = strbyte(buf, offset + 1)
	local c = strbyte(buf, offset + 2)
	local d = strbyte(buf, offset + 3)
	local v = a + b * 256 + c * 65536 + d * 16777216
	if v >= 2147483648 then v = v - 4294967296 end
	return v, offset + 4
end

--- Read an unsigned 32-bit integer.
---@param buf string
---@param offset integer
---@return integer value
---@return integer next_offset
function M.readU32(buf, offset)
	return M.readI32(buf, offset)
end

--- Read a 32-bit float.
---@param buf string
---@param offset integer
---@return number value
---@return integer next_offset
function M.readF32(buf, offset)
	local p = ffi.new("uint8_t[4]")
	ffi.copy(p, buf:sub(offset, offset + 3), 4)
	local u = byte_mod.union_le(p)
	return u.f32, offset + 4
end

--- Read a 64-bit float.
---@param buf string
---@param offset integer
---@return number value
---@return integer next_offset
function M.readF64(buf, offset)
	local p = ffi.new("uint8_t[8]")
	ffi.copy(p, buf:sub(offset, offset + 7), 8)
	local u = byte_mod.union_le(p)
	return u.f64, offset + 8
end

--- Write a length-prefixed list of 32-bit integers.
---@param list integer[]
---@return string
function M.writeI32List(list)
	local out = { M.writeU16(#list) }
	for _, v in ipairs(list) do
		table.insert(out, M.writeI32(v))
	end
	return table.concat(out)
end

--- Read a length-prefixed list of 32-bit integers.
---@param buf string
---@param offset integer
---@return integer[] value
---@return integer next_offset
function M.readI32List(buf, offset)
	local len, nextI = M.readU16(buf, offset)
	---@type integer[]
	local result = {}
	for _ = 1, len do
		local v, n = M.readI32(buf, nextI)
		table.insert(result, v)
		nextI = n
	end
	return result, nextI
end

M.HEADER_SIZE = 7

--- Write a packet header.
---@param id integer packet ID
---@param bodyLen integer body length
---@return string
function M.writeHeader(id, bodyLen)
	return M.writeU16(id) .. "\000" .. M.writeU32(bodyLen)
end

--- Read a packet header.
---@param buf string
---@param offset integer
---@return integer id
---@return integer bodyLen
---@return integer next_offset
function M.readHeader(buf, offset)
	local id, n1 = M.readU16(buf, offset)
	local bodyLen, n2 = M.readU32(buf, n1 + 1)
	return id, bodyLen, n2
end

return M
