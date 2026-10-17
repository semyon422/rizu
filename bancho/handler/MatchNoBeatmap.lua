--- Packet 54: MATCH_NO_BEATMAP
--- Player signals they don't have the beatmap.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match no beatmap handler data (empty).
---@class bancho.handler.MatchNoBeatmapData

--- Packet 54: MATCH_NO_BEATMAP
---@class bancho.handler.MatchNoBeatmap: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchNoBeatmap
local MatchNoBeatmap = IPacketHandler + {}

---@return bancho.handler.MatchNoBeatmapData
function MatchNoBeatmap:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchNoBeatmapData
function MatchNoBeatmap:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	slot.status = SlotStatus.NO_MAP

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchNoBeatmap
