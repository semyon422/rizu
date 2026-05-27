local Binary = require("bancho.protocol.Binary")
local class = require("class")

local PacketReader = class()

function PacketReader:new(body)
	self.body = body
	self.pos = 1
	return self
end

function PacketReader:remaining()
	return #self.body - self.pos + 1
end

function PacketReader:hasMore()
	return self.pos <= #self.body
end

function PacketReader:skip(n)
	self.pos = self.pos + n
end

function PacketReader:readULEB128()
	local v, n = Binary.readULEB128(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readString()
	local v, n = Binary.readString(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readI8()
	local v, n = Binary.readI8(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readU8()
	local v, n = Binary.readU8(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readI16()
	local v, n = Binary.readI16(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readU16()
	local v, n = Binary.readU16(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readI32()
	local v, n = Binary.readI32(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readU32()
	local v, n = Binary.readU32(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readF32()
	local v, n = Binary.readF32(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readF64()
	local v, n = Binary.readF64(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readI32List()
	local v, n = Binary.readI32List(self.body, self.pos)
	self.pos = n
	return v
end

function PacketReader:readBytes(n)
	local v = self.body:sub(self.pos, self.pos + n - 1)
	self.pos = self.pos + n
	return v
end

return PacketReader
