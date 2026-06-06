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

	slot.status = SlotStatus.COMPLETED

	local immune = {}
	for i = 0, 15 do
		local current = match.slots[i]
		if current.status == SlotStatus.PLAYING then
			return
		end
		if current.player and current.status ~= SlotStatus.COMPLETED then
			immune[#immune + 1] = current.player
		end
	end

	for i = 0, 15 do
		local current = match.slots[i]
		if current.status == SlotStatus.COMPLETED then
			current.status = SlotStatus.NOT_READY
		end
		current.loaded = false
		current.skipped = false
	end
	match.in_progress = false

	match:broadcast(ServerPackets.matchComplete(), server.players, immune)
	server.chat_manager:notifyMatchUpdate(match, server.match_manager:buildMatchData(match), server.channels, true)
end

return MatchComplete
