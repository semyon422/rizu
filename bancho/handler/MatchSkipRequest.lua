--- Packet 60: MATCH_SKIP_REQUEST
--- Player votes to skip the match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match skip request handler data (empty).
---@class bancho.handler.MatchSkipRequestData

--- Packet 60: MATCH_SKIP_REQUEST
---@class bancho.handler.MatchSkipRequest: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchSkipRequest
local MatchSkipRequest = IPacketHandler + {}

---@return bancho.handler.MatchSkipRequestData
function MatchSkipRequest:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchSkipRequestData
function MatchSkipRequest:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	slot.skipped = true

	-- Notify all players of this skip vote
	local skippedPkt = ServerPackets.matchPlayerSkipped(player.id)
	for i = 0, 15 do
		if match.slots[i].player ~= nil then
			match.slots[i].player:enqueue(skippedPkt)
		end
	end

	-- Check if all playing players have skipped
	for i = 0, 15 do
		if match.slots[i].status == SlotStatus.PLAYING and not match.slots[i].skipped then
			return -- Not all players have skipped yet
		end
	end

	-- All players have skipped, send skip signal
	local skipPkt = ServerPackets.matchSkip()
	for i = 0, 15 do
		if match.slots[i].player ~= nil then
			match.slots[i].player:enqueue(skipPkt)
		end
	end
end

return MatchSkipRequest
