--- Packet 44: MATCH_START
--- Host starts the match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match start handler data (empty).
---@class bancho.handler.MatchStartData

--- Packet 44: MATCH_START
---@class bancho.handler.MatchStart: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchStart
local MatchStart = IPacketHandler + {}

---@return bancho.handler.MatchStartData
function MatchStart:parse(reader, bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchStartData
function MatchStart:handle(server, player, data)
	if not player.match then return end

	local match = player.match

	-- Only host can start
	if match.host_id ~= player.id then return end

	local no_map = {}
	for i = 0, 15 do
		local slot = match.slots[i]
		if slot.player ~= nil or slot.player_id ~= nil then
			if slot.status ~= SlotStatus.NO_MAP then
				slot.status = SlotStatus.PLAYING
			else
				local target = slot.player
				if not target and slot.player_id then
					target = server.players:get(nil, slot.player_id)
				end
				if target then
					no_map[#no_map + 1] = target
				end
			end
		end
	end

	server.match_manager:start(match)

	local pkt = ServerPackets.matchStart(server.match_manager:buildMatchData(match))
	match:broadcast(pkt, server.players, no_map)
	server.chat_manager:notifyMatchUpdate(match, server.match_manager:buildMatchData(match), server.channels, true)
end

return MatchStart
