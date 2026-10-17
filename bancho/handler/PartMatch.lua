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

	player.match = nil

	-- If match has no players, dispose it
	local has_players = false
	for i = 0, 15 do
		if match.slots[i].player ~= nil or match.slots[i].player_id ~= nil then
			has_players = true
			break
		end
	end

	if not has_players then
		-- Broadcast disposal to lobby
		local lobby_ch = server.channels:get("#lobby")
		if lobby_ch then
			for _, p in pairs(lobby_ch.players) do
				p:enqueue(ServerPackets.disposeMatch(match.id))
			end
		end
		server.match_manager:dispose(match.id)
	else
		if match.host_id == player.id then
			local new_host = server.match_manager:getNextHost(match)
			if new_host then
				server.match_manager:transferHost(match, new_host)
				local host_pkt = ServerPackets.matchTransferHost()
				if server.players._dict then
					server.players._dict:rpush("pq:" .. new_host.token, host_pkt)
				else
					new_host:enqueue(host_pkt)
				end
			end
		end

		-- Broadcast updated match state to all remaining players + the leaving player
		local match_data = server.match_manager:buildMatchData(match)
		player:enqueue(ServerPackets.updateMatch(match_data))
		match:broadcast(ServerPackets.updateMatch(match_data), server.players)

		-- Also notify lobby
		server.chat_manager:notifyMatchUpdate(match, match_data, server.channels, true)
	end
end

return PartMatch
