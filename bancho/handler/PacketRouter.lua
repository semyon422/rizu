--- Central packet router for the Bancho protocol.
---
--- Maintains two handler registries: "all" (unrestricted players) and
--- "restricted" (banned/restricted players). Dispatch loops through
--- incoming binary data, reads headers, and invokes handlers by packet ID.

local class = require("class")

--- Tracks a single handled packet for status page reporting.
---@class bancho.handler.HandledPacket
---@field name string
---@field id integer

--- Packet router: registers and dispatches Bancho packet handlers.
---@class bancho.handler.PacketRouter
---@operator call: bancho.handler.PacketRouter
---@field handlers_all {[integer]: bancho.handler.IPacketHandler}
---@field handlers_restricted {[integer]: bancho.handler.IPacketHandler}
---@field handled_packets bancho.handler.HandledPacket[]
local PacketRouter = class()

function PacketRouter:new()
	self.handlers_all = {}
	self.handlers_restricted = {}
	self.handled_packets = {}
	return self
end

--- Register a handler for a packet ID.
--- If `restricted` is true, the handler is also registered in the restricted map
--- (allowing restricted players to use it).
---@param packet_id integer
---@param handler bancho.handler.IPacketHandler
---@param handler_name? string human-readable name for tracking
---@param restricted? boolean
function PacketRouter:register(packet_id, handler, handler_name, restricted)
	self.handlers_all[packet_id] = handler
	if restricted then
		self.handlers_restricted[packet_id] = handler
	end
	if handler_name then
		table.insert(self.handled_packets, { name = handler_name, id = packet_id })
	end
end

--- Get the handler registry for a player based on restriction status.
---@param player bancho.model.Player
---@return {[integer]: bancho.handler.IPacketHandler}
function PacketRouter:getRegistry(player)
	if player.restricted then
		return self.handlers_restricted
	end
	return self.handlers_all
end

--- Dispatch all packets in the binary data for a player.
--- Reads headers in a loop, looks up the handler, parses body, and invokes it.
--- Unknown packet IDs are silently skipped (body bytes consumed).
---@param player bancho.model.Player
---@param data string raw binary data
function PacketRouter:dispatch(player, data)
	if #data == 0 then return end

	local registry = self:getRegistry(player)
	local reader = require("bancho.protocol.PacketReader")(data)

	while reader:hasMore() do
		local header = reader:readHeader()
		if not header then
			break
		end

		local handler = registry[header.id]
		if not handler then
			-- Unknown/unhandled packet — skip its body.
			reader:skip(header.bodyLen)
		else
			local result = handler:parse(reader, header.bodyLen)
			handler:handle(self._server, player, result)
		end
	end
end

--- Set the server reference (used by handlers via self._server).
---@param server bancho.server.BanchoServer
function PacketRouter:setServer(server)
	self._server = server
end

return PacketRouter
