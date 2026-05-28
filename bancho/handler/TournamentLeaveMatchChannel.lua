--- Packet 109: TOURNAMENT_LEAVE_MATCH_CHANNEL
--- Leave tournament match channel.
---
--- NOTE: Tournament system not implemented. This handler is a stub.

local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Tournament leave match channel handler data (empty).
---@class bancho.handler.TournamentLeaveMatchChannelData

--- Packet 109: TOURNAMENT_LEAVE_MATCH_CHANNEL
---@class bancho.handler.TournamentLeaveMatchChannel: bancho.handler.IPacketHandler
---@operator call: bancho.handler.TournamentLeaveMatchChannel
local TournamentLeaveMatchChannel = IPacketHandler + {}

---@return bancho.handler.TournamentLeaveMatchChannelData
function TournamentLeaveMatchChannel:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.TournamentLeaveMatchChannelData
function TournamentLeaveMatchChannel:handle(server, player, data)
	-- TODO: tournament system not implemented
end

return TournamentLeaveMatchChannel
