--- Packet 32: JOIN_MATCH
--- Client joins an existing multiplayer match.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Join match handler data.
---@class bancho.handler.JoinMatchData
---@field match_id integer
---@field password string

--- Packet 32: JOIN_MATCH
---@class bancho.handler.JoinMatch: bancho.handler.IPacketHandler
---@operator call: bancho.handler.JoinMatch
local JoinMatch = IPacketHandler + {}

---@return bancho.handler.JoinMatchData
function JoinMatch:parse(reader, bodyLen)
	return {
		match_id = reader:readI32(),
		password = reader:readString(),
	}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.JoinMatchData
function JoinMatch:handle(server, player, data)
	local match = server.matches:get(data.match_id)
	if not match then
		player:enqueue(ServerPackets.matchJoinFail())
		return
	end

	-- Restricted/silenced players can't join matches
	if player.restricted or player.silenced then
		player:enqueue(
			ServerPackets.matchJoinFail() ..
			ServerPackets.notification("Multiplayer is not available while restricted.")
		)
		return
	end

	-- Already in this match — just re-send state
	if player.match and player.match.id == match.id then
		local match_data = server.match_manager:buildMatchData(match)
		player:enqueue(ServerPackets.matchJoinSuccess(match_data))
		return
	end

	-- Leave current match if in one
	if player.match then
		server.match_manager:removePlayer(player.match, player)
		player.match = nil
	end

	-- Check password (empty password from client matches empty or no password)
	if match.passwd ~= "" and data.password ~= match.passwd then
		player:enqueue(ServerPackets.matchJoinFail())
		return
	end

	-- Restore match chat channel when loading from dict.
	if not match.chat then
		match.chat = server.channels:get("#multi_" .. match.id)
	end

	-- Add player to match
	if not server.match_manager:addPlayer(match, player) then
		player:enqueue(ServerPackets.matchJoinFail())
		return
	end

	-- Set player's match reference
	player.match = match

	-- Send join success
	local match_data = server.match_manager:buildMatchData(match)
	player:enqueue(ServerPackets.matchJoinSuccess(match_data))

	-- Broadcast match state to lobby and match participants
	server.chat_manager:notifyMatchUpdate(match, match_data, server.channels, true)
end

return JoinMatch
