local Binary = require("bancho.protocol.Binary")
local class = require("class")

local PacketWriter = class()

function PacketWriter:new()
	self.body = ""
	return self
end

function PacketWriter:writeRaw(s)
	self.body = self.body .. s
end

function PacketWriter:writeULEB128(v)
	self.body = self.body .. Binary.writeULEB128(v)
end

function PacketWriter:writeString(s)
	self.body = self.body .. Binary.writeString(s)
end

function PacketWriter:writeI8(v)
	self.body = self.body .. Binary.writeI8(v)
end

function PacketWriter:writeU8(v)
	self.body = self.body .. Binary.writeU8(v)
end

function PacketWriter:writeI16(v)
	self.body = self.body .. Binary.writeI16(v)
end

function PacketWriter:writeU16(v)
	self.body = self.body .. Binary.writeU16(v)
end

function PacketWriter:writeI32(v)
	self.body = self.body .. Binary.writeI32(v)
end

function PacketWriter:writeU32(v)
	self.body = self.body .. Binary.writeU32(v)
end

function PacketWriter:writeI64(v)
	self.body = self.body .. Binary.writeI64(v)
end

function PacketWriter:writeF32(v)
	self.body = self.body .. Binary.writeF32(v)
end

function PacketWriter:writeF64(v)
	self.body = self.body .. Binary.writeF64(v)
end

function PacketWriter:writeI32List(list)
	self.body = self.body .. Binary.writeI32List(list)
end

function PacketWriter:finalize(id)
	local header = Binary.writeHeader(id, #self.body)
	return header .. self.body
end

return PacketWriter
