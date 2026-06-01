--- Packet 39: MATCH_READY
--- Client toggles ready status in a match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match ready handler data (empty).
---@class bancho.handler.MatchReadyData

--- Packet 39: MATCH_READY
---@class bancho.handler.MatchReady: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchReady
local MatchReady = IPacketHandler + {}

---@return bancho.handler.MatchReadyData
function MatchReady:parse(reader, bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchReadyData
function MatchReady:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	-- Toggle ready status
	if slot.status == SlotStatus.READY then
		slot.status = SlotStatus.NOT_READY
	else
		slot.status = SlotStatus.READY
	end

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchReady
