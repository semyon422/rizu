--- Packet 2: LOGOUT
--- Client logs out. Server removes player and broadcasts logout.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Logout handler data (empty).
---@class bancho.handler.LogoutData

--- Packet 2: LOGOUT
---@class bancho.handler.Logout: bancho.handler.IPacketHandler
---@operator call: bancho.handler.Logout
local Logout = IPacketHandler + {}

---@return bancho.handler.LogoutData
function Logout:parse(reader, bodyLen)
	reader:readI32() -- reserved
	return {}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.LogoutData
function Logout:handle(server, player, data)
	-- Remove player from all channels
	for _, channel in ipairs(server.channels:all()) do
		if channel:contains(player) then
			server.chat_manager:leave(channel, player)

			-- Broadcast channel info update
			local count = 0
			for _ in pairs(channel.players) do count = count + 1 end
			local chan_info = ServerPackets.channelInfo(channel.real_name, channel.topic or "", count)
			for _, other in ipairs(server.players:all()) do
				if channel:canRead(other.priv) then
					other:enqueue(chan_info)
				end
			end
		end
	end

	-- Broadcast logout to all other players
	server.players:enqueue(ServerPackets.userLogout(player.id), {player})

	-- Remove player from collection
	server.players:remove(player)
	player.is_online = false

	-- If player is in a match, remove them
	if player.match then
		local match = player.match
		server.match_manager:removePlayer(match, player)
		player.match = nil

		local has_players = false
		for i = 0, 15 do
			if match.slots[i].player ~= nil or match.slots[i].player_id ~= nil then
				has_players = true
				break
			end
		end

		if not has_players then
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

			local match_data = server.match_manager:buildMatchData(match)
			match:broadcast(ServerPackets.updateMatch(match_data), server.players)
			server.chat_manager:notifyMatchUpdate(match, match_data, server.channels, true)
		end
	end

	-- If player is spectating, stop
	if player.spectating then
		player.spectating:removeSpectator(player)
		player.spectating = nil
	end

	-- If player has spectators, notify them
	for _, spectator in ipairs(player.spectators) do
		spectator:enqueue(ServerPackets.spectatorLeft(player.id))
	end
	player.spectators = {}
end

return Logout
