--- Packet 30: JOIN_LOBBY
--- Player joins the multiplayer lobby and receives all active matches.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Join lobby handler data (empty).
---@class bancho.handler.JoinLobbyData

--- Packet 30: JOIN_LOBBY
---@class bancho.handler.JoinLobby: bancho.handler.IPacketHandler
---@operator call: bancho.handler.JoinLobby
local JoinLobby = IPacketHandler + {}

---@return bancho.handler.JoinLobbyData
function JoinLobby:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.JoinLobbyData
function JoinLobby:handle(server, player, data)
	player.in_lobby = true

	for _, match in ipairs(server.matches:all()) do
		local match_data = server.match_manager:buildMatchData(match)
		player:enqueue(ServerPackets.newMatch(match_data))
	end
end

return JoinLobby
