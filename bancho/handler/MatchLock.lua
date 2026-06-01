--- Packet 40: MATCH_LOCK
--- Host locks or unlocks a slot in the match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match lock handler data.
---@class bancho.handler.MatchLockData
---@field slot_id integer

--- Packet 40: MATCH_LOCK
---@class bancho.handler.MatchLock: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchLock
local MatchLock = IPacketHandler + {}

---@return bancho.handler.MatchLockData
function MatchLock:parse(reader, bodyLen)
	return { slot_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchLockData
function MatchLock:handle(server, player, data)
	if not player.match then return end

	-- Only host can lock slots
	if player.match.host_id ~= player.id then return end

	-- Validate slot range
	if data.slot_id < 0 or data.slot_id > 15 then return end

	local slot = player.match.slots[data.slot_id]

	if slot.status == SlotStatus.LOCKED then
		slot.status = SlotStatus.OPEN
	else
		slot.status = SlotStatus.LOCKED
	end

	-- Broadcast updated match state to all players in match slots
	player.match:broadcast(ServerPackets.updateMatch(server.match_manager:buildMatchData(player.match)), server.players)
end

return MatchLock
