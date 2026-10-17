--- Packet 55: MATCH_NOT_READY
--- Player goes back to not-ready state.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match not ready handler data (empty).
---@class bancho.handler.MatchNotReadyData

--- Packet 55: MATCH_NOT_READY
---@class bancho.handler.MatchNotReady: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchNotReady
local MatchNotReady = IPacketHandler + {}

---@return bancho.handler.MatchNotReadyData
function MatchNotReady:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchNotReadyData
function MatchNotReady:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	slot.status = SlotStatus.NOT_READY

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchNotReady
