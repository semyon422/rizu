--- Packet 90: MATCH_CHANGE_PASSWORD
--- Host changes the match password.

local ServerPackets = require("bancho.protocol.ServerPackets")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Match change password handler data.
---@class bancho.handler.MatchChangePasswordData: bancho.protocol.MultiplayerMatch

--- Packet 90: MATCH_CHANGE_PASSWORD
---@class bancho.handler.MatchChangePassword: bancho.handler.IPacketHandler
---@operator call: bancho.handler.MatchChangePassword
local MatchChangePassword = IPacketHandler + {}

---@return bancho.handler.MatchChangePasswordData
function MatchChangePassword:parse(reader, bodyLen)
	return ComplexTypes.readMatch(reader)
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.MatchChangePasswordData
function MatchChangePassword:handle(server, player, data)
	if not player.match then return end

	-- Only host can change password
	if player.match.host_id ~= player.id then return end

	-- Validate: host ID must match
	if data.host_id ~= player.id then return end

	-- Change password
	local match = player.match
	match.passwd = data.passwd

	-- Send password change packet
	local pkt = ServerPackets.matchChangePassword(data.passwd)
	for i = 0, 15 do
		if match.slots[i].player ~= nil then
			match.slots[i].player:enqueue(pkt)
		end
	end

	-- Broadcast updated match state
	local match_data = server.match_manager:buildMatchData(match)
	if match.chat then
		for _, p in pairs(match.chat.players) do
			p:enqueue(ServerPackets.updateMatch(match_data))
		end
	end
end

return MatchChangePassword
