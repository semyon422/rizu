--- Packet 2: LOGOUT
--- Client logs out. Server removes player and broadcasts logout.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Logout handler data (empty).
---@class bancho.handler.LogoutData

--- Packet 2: LOGOUT
---@class bancho.handler.Logout: bancho.handler.IPacketHandler
---@operator call: bancho.handler.Logout
local Logout = IPacketHandler + {}

---@return bancho.handler.LogoutData
function Logout:parse(reader, bodyLen)
	reader:readI32() -- reserved
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.LogoutData
function Logout:handle(server, player, data)
	-- Broadcast logout to all other players
	server.players:enqueue(ServerPackets.userLogout(player.id), {player})

	-- Remove player from collection
	server.players:remove(player)
	player.is_online = false

	-- If player is in a match, remove them
	if player.match then
		server.match_manager:removePlayer(player.match, player)
		player.match = nil
	end

	-- If player is spectating, stop
	if player.spectating then
		player.spectating:removeSpectator(player)
		player.spectating = nil
	end

	-- If player has spectators, notify them
	for _, spectator in ipairs(player.spectators) do
		spectator:enqueue(ServerPackets.spectatorLeft(player.id))
	end
	player.spectators = {}
end

return Logout
