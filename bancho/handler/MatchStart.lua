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

	-- Check all players are ready (unless already in progress)
	for i = 0, 15 do
		if match.slots[i].player ~= nil and match.slots[i].status ~= SlotStatus.READY then
			return -- Not all ready, ignore
		end
	end

	-- Set all players to PLAYING status
	for i = 0, 15 do
		if match.slots[i].player ~= nil then
			match.slots[i].status = SlotStatus.PLAYING
		end
	end

	match.in_progress = true
	server.match_manager:start(match)

	-- Send MATCH_START to all players in match slots
	match:broadcast(ServerPackets.matchStart(server.match_manager:buildMatchData(match)), server.players)
end

return MatchStart
