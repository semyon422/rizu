--- Packet 59: MATCH_HAS_BEATMAP
--- Player signals they have the beatmap (came back from no-map state).

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match has beatmap handler data (empty).
---@class bancho.handler.MatchHasBeatmapData

--- Packet 59: MATCH_HAS_BEATMAP
---@class bancho.handler.MatchHasBeatmap: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchHasBeatmap
local MatchHasBeatmap = IPacketHandler + {}

---@return bancho.handler.MatchHasBeatmapData
function MatchHasBeatmap:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchHasBeatmapData
function MatchHasBeatmap:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	slot.status = SlotStatus.NOT_READY

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchHasBeatmap
