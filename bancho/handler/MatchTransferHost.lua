--- Packet 70: MATCH_TRANSFER_HOST
--- Host transfers match host to another player.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match transfer host handler data.
---@class bancho.handler.MatchTransferHostData
---@field slot_id integer

--- Packet 70: MATCH_TRANSFER_HOST
---@class bancho.handler.MatchTransferHost: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchTransferHost
local MatchTransferHost = IPacketHandler + {}

---@return bancho.handler.MatchTransferHostData
function MatchTransferHost:parse(reader, bodyLen)
	return { slot_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchTransferHostData
function MatchTransferHost:handle(server, player, data)
	if not player.match then return end

	-- Only host can transfer
	if player.match.host_id ~= player.id then return end

	-- Validate slot range
	if data.slot_id < 0 or data.slot_id > 15 then return end

	local match = player.match
	local targetSlot = match.slots[data.slot_id]
	if not targetSlot.player then return end

	-- Transfer host
	server.match_manager:transferHost(match, targetSlot.player)

	-- Broadcast transfer host packet
	match:broadcast(ServerPackets.matchTransferHost(), server.players)

	-- Broadcast updated match state to all players in match slots
	match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(match)), server.players)
end

return MatchTransferHost
