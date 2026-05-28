--- Packet 33: PART_MATCH
--- Client leaves their current multiplayer match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Part match handler data (empty).
---@class bancho.handler.PartMatchData

--- Packet 33: PART_MATCH
---@class bancho.handler.PartMatch: bancho.handler.IPacketHandler
---@operator call: bancho.handler.PartMatch
local PartMatch = IPacketHandler + {}

---@return bancho.handler.PartMatchData
function PartMatch:parse(reader, bodyLen)
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.PartMatchData
function PartMatch:handle(server, player, data)
	if not player.match then return end

	local match = player.match

	-- Remove player from match
	server.match_manager:removePlayer(match, player)

	-- Broadcast updated match state
	local match_data = server.match_manager:buildMatchData(match)
	match.chat:add(player) -- temporarily add for broadcast
	if match.chat then
		for _, p in pairs(match.chat.players) do
			p:enqueue(ServerPackets.updateMatch(match_data))
		end
	end

	player.match = nil

	-- If match has no players, dispose it
	local has_players = false
	for i = 0, 15 do
		if match.slots[i].player ~= nil then
			has_players = true
			break
		end
	end
	if not has_players then
		server.match_manager:dispose(match.id)
	end
end

return PartMatch
