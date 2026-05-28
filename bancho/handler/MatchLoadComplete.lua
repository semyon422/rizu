--- Packet 52: MATCH_LOAD_COMPLETE
--- Player signals they have loaded the map and are ready to play.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match load complete handler data (empty).
---@class bancho.handler.MatchLoadCompleteData

--- Packet 52: MATCH_LOAD_COMPLETE
---@class bancho.handler.MatchLoadComplete: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchLoadComplete
local MatchLoadComplete = IPacketHandler + {}

---@return bancho.handler.MatchLoadCompleteData
function MatchLoadComplete:parse(reader, bodyLen)
	reader:skip(bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchLoadCompleteData
function MatchLoadComplete:handle(server, player, data)
	if not player.match then return end

	local match = player.match
	local slot = match:getSlot(player)
	if not slot then return end

	slot.loaded = true

	-- Check if any player is still playing (not loaded)
	local hasPlaying = false
	for i = 0, 15 do
		if match.slots[i].status == SlotStatus.PLAYING and not match.slots[i].loaded then
			hasPlaying = true
			break
		end
	end

	-- If all players are loaded, send all players loaded signal
	if not hasPlaying then
		local pkt = ServerPackets.matchAllPlayersLoaded()
		for i = 0, 15 do
			if match.slots[i].player ~= nil then
				match.slots[i].player:enqueue(pkt)
			end
		end
	end
end

return MatchLoadComplete
