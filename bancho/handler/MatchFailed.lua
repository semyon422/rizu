--- Packet 56: MATCH_FAILED
--- Player failed the match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match failed handler data (empty).
---@class bancho.handler.MatchFailedData

--- Packet 56: MATCH_FAILED
---@class bancho.handler.MatchFailed: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchFailed
local MatchFailed = IPacketHandler + {}

---@return bancho.handler.MatchFailedData
function MatchFailed:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchFailedData
function MatchFailed:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slotId = match:getSlotId(player)
	if slotId == nil then return end

	-- Notify all players that this player failed
	match:broadcast(ServerPackets.matchPlayerFailed(slotId), server.players)
end

return MatchFailed
