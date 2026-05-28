--- Packet 21: CANT_SPECTATE
--- Spectator informs host that they can't spectate anymore.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Cant spectate handler data (empty).
---@class bancho.handler.CantSpectateData

--- Packet 21: CANT_SPECTATE
---@class bancho.handler.CantSpectate: bancho.handler.IPacketHandler
---@operator call: bancho.handler.CantSpectate
local CantSpectate = IPacketHandler + {}

---@return bancho.handler.CantSpectateData
function CantSpectate:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.CantSpectateData
function CantSpectate:handle(server, player, data)
	if not player.spectating then return end

	local host = player.spectating

	if not player.stealth then
		local pkt = ServerPackets.spectatorCantSpectate(player.id)

		host:enqueue(pkt)

		for _, s in ipairs(host.spectators) do
			s:enqueue(pkt)
		end
	end

	-- Remove spectator relationship
	host:removeSpectator(player)
	player.spectating = nil
end

return CantSpectate
