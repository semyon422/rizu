local Binary = require("bancho.protocol.Binary")
local class = require("class")

--- Packet writer for Bancho protocol binary data.
---@class bancho.protocol.PacketWriter
---@operator call: bancho.protocol.PacketWriter
---@field body string
local PacketWriter = class()

function PacketWriter:new()
	self.body = ""
	return self
end

--- Write raw bytes.
---@param s string
function PacketWriter:writeRaw(s)
	self.body = self.body .. s
end

--- Write an unsigned LEB128 value.
---@param v integer
function PacketWriter:writeULEB128(v)
	self.body = self.body .. Binary.writeULEB128(v)
end

--- Write a null-terminated or length-prefixed string.
---@param s string
function PacketWriter:writeString(s)
	self.body = self.body .. Binary.writeString(s)
end

--- Write a signed 8-bit integer.
---@param v integer
function PacketWriter:writeI8(v)
	self.body = self.body .. Binary.writeI8(v)
end

--- Write an unsigned 8-bit integer.
---@param v integer
function PacketWriter:writeU8(v)
	self.body = self.body .. Binary.writeU8(v)
end

--- Write a signed 16-bit integer.
---@param v integer
function PacketWriter:writeI16(v)
	self.body = self.body .. Binary.writeI16(v)
end

--- Write an unsigned 16-bit integer.
---@param v integer
function PacketWriter:writeU16(v)
	self.body = self.body .. Binary.writeU16(v)
end

--- Write a signed 32-bit integer.
---@param v integer
function PacketWriter:writeI32(v)
	self.body = self.body .. Binary.writeI32(v)
end

--- Write an unsigned 32-bit integer.
---@param v integer
function PacketWriter:writeU32(v)
	self.body = self.body .. Binary.writeU32(v)
end

--- Write a signed 64-bit integer.
---@param v integer
function PacketWriter:writeI64(v)
	self.body = self.body .. Binary.writeI64(v)
end

--- Write a 32-bit float.
---@param v number
function PacketWriter:writeF32(v)
	self.body = self.body .. Binary.writeF32(v)
end

--- Write a 64-bit float.
---@param v number
function PacketWriter:writeF64(v)
	self.body = self.body .. Binary.writeF64(v)
end

--- Write a length-prefixed list of 32-bit integers.
---@param list integer[]
function PacketWriter:writeI32List(list)
	self.body = self.body .. Binary.writeI32List(list)
end

--- Finalize the packet with a header.
---@param id integer packet ID
---@return string complete packet with header
function PacketWriter:finalize(id)
	local header = Binary.writeHeader(id, #self.body)
	return header .. self.body
end

return PacketWriter
