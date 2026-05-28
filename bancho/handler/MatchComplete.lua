--- Packet 49: MATCH_COMPLETE
--- Client completes the match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match complete handler data (empty).
---@class bancho.handler.MatchCompleteData

--- Packet 49: MATCH_COMPLETE
---@class bancho.handler.MatchComplete: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchComplete
local MatchComplete = IPacketHandler + {}

---@return bancho.handler.MatchCompleteData
function MatchComplete:parse(reader, bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchCompleteData
function MatchComplete:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	-- Mark player as completed
	slot.status = SlotStatus.COMPLETED

	-- Broadcast match complete
	if match.chat then
		for _, p in pairs(match.chat.players) do
			p:enqueue(ServerPackets.matchComplete())
		end
	end
end

return MatchComplete
