local Binary = require("bancho.protocol.Binary")
local class = require("class")

--- Packet reader for Bancho protocol binary data.
---@class bancho.protocol.PacketReader
---@operator call: bancho.protocol.PacketReader
---@field body string
---@field pos integer
local PacketReader = class()

function PacketReader:new(body)
	self.body = body
	self.pos = 1
	return self
end

--- Get remaining bytes.
---@return integer
function PacketReader:remaining()
	return #self.body - self.pos + 1
end

--- Check if there are more bytes to read.
---@return boolean
function PacketReader:hasMore()
	return self.pos <= #self.body
end

--- Skip n bytes.
---@param n integer
function PacketReader:skip(n)
	self.pos = self.pos + n
end

--- Read an unsigned LEB128 value.
---@return integer
function PacketReader:readULEB128()
	local v, n = Binary.readULEB128(self.body, self.pos)
	self.pos = n
	return v
end

--- Read a null-terminated or length-prefixed string.
---@return string
function PacketReader:readString()
	local v, n = Binary.readString(self.body, self.pos)
	self.pos = n
	return v
end

--- Ensure there are enough bytes remaining.
---@param needed integer
local function checkBounds(self, needed)
	if self.pos + needed - 1 > #self.body then
		error(string.format("PacketReader: read past end of body (pos=%d, needed=%d, bodyLen=%d)",
			self.pos, needed, #self.body))
	end
end

--- Read a signed 8-bit integer.
---@return integer
function PacketReader:readI8()
	checkBounds(self, 1)
	local v, n = Binary.readI8(self.body, self.pos)
	self.pos = n
	return v
end

--- Read an unsigned 8-bit integer.
---@return integer
function PacketReader:readU8()
	checkBounds(self, 1)
	local v, n = Binary.readU8(self.body, self.pos)
	self.pos = n
	return v
end

--- Read a signed 16-bit integer.
---@return integer
function PacketReader:readI16()
	checkBounds(self, 2)
	local v, n = Binary.readI16(self.body, self.pos)
	self.pos = n
	return v
end

--- Read an unsigned 16-bit integer.
---@return integer
function PacketReader:readU16()
	checkBounds(self, 2)
	local v, n = Binary.readU16(self.body, self.pos)
	self.pos = n
	return v
end

--- Read a signed 32-bit integer.
---@return integer
function PacketReader:readI32()
	checkBounds(self, 4)
	local v, n = Binary.readI32(self.body, self.pos)
	self.pos = n
	return v
end

--- Read an unsigned 32-bit integer.
---@return integer
function PacketReader:readU32()
	checkBounds(self, 4)
	local v, n = Binary.readU32(self.body, self.pos)
	self.pos = n
	return v
end

--- Read a 32-bit float.
---@return number
function PacketReader:readF32()
	checkBounds(self, 4)
	local v, n = Binary.readF32(self.body, self.pos)
	self.pos = n
	return v
end

--- Read a 64-bit float.
---@return number
function PacketReader:readF64()
	checkBounds(self, 8)
	local v, n = Binary.readF64(self.body, self.pos)
	self.pos = n
	return v
end

--- Read a length-prefixed list of 32-bit integers.
---@return integer[]
function PacketReader:readI32List()
	local v, n = Binary.readI32List(self.body, self.pos)
	self.pos = n
	return v
end

--- Read raw bytes.
---@param n integer count
---@return string
function PacketReader:readBytes(n)
	local v = self.body:sub(self.pos, self.pos + n - 1)
	self.pos = self.pos + n
	return v
end

--- Read a packet header (u16 id + u8 padding + u32 body length).
---@return {id: integer, bodyLen: integer}?
function PacketReader:readHeader()
	if self.pos + 6 > #self.body then
		return nil
	end
	local id, bodyLen, nextPos = Binary.readHeader(self.body, self.pos)
	self.pos = nextPos
	return {id = id, bodyLen = bodyLen}
end

return PacketReader
