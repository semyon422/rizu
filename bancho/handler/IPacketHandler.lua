--- Base class for Bancho packet handlers.
---
--- Each concrete handler inherits this class and implements `parse` and `handle`.

local class = require("class")

--- Packet handler interface.
---@class bancho.handler.IPacketHandler
---@operator call: bancho.handler.IPacketHandler
local IPacketHandler = class()

--- Parse the packet body from the reader.
--- Subclasses read structured data or skip bodyLen bytes.
--- Must consume exactly bodyLen bytes from the reader.
---@param reader bancho.protocol.PacketReader
---@param bodyLen integer
---@return table data
function IPacketHandler:parse(reader, bodyLen)
	error("not implemented")
end

--- Execute business logic for this packet.
---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data table parsed data from parse()
function IPacketHandler:handle(server, player, data)
	error("not implemented")
end

return IPacketHandler
