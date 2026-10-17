--- Packet 108: TOURNAMENT_JOIN_MATCH_CHANNEL
--- Join tournament match channel.
---
--- NOTE: Tournament system not implemented. This handler is a stub.

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Tournament join match channel handler data (empty).
---@class bancho.handler.TournamentJoinMatchChannelData

--- Packet 108: TOURNAMENT_JOIN_MATCH_CHANNEL
---@class bancho.handler.TournamentJoinMatchChannel: bancho.handler.IPacketHandler
---@operator call: bancho.handler.TournamentJoinMatchChannel
local TournamentJoinMatchChannel = IPacketHandler + {}

---@return bancho.handler.TournamentJoinMatchChannelData
function TournamentJoinMatchChannel:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.TournamentJoinMatchChannelData
function TournamentJoinMatchChannel:handle(server, player, data)
	-- TODO: tournament system not implemented
end

return TournamentJoinMatchChannel
