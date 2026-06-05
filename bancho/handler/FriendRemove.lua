--- Packet 74: FRIEND_REMOVE
--- Player removes another player from friends.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Friend remove handler data.
---@class bancho.handler.FriendRemoveData
---@field user_id integer

--- Packet 74: FRIEND_REMOVE
---@class bancho.handler.FriendRemove: bancho.handler.IPacketHandler
---@operator call: bancho.handler.FriendRemove
local FriendRemove = IPacketHandler + {}

---@return bancho.handler.FriendRemoveData
function FriendRemove:parse(reader, bodyLen)
	return { user_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.FriendRemoveData
function FriendRemove:handle(server, player, data)
	local target = server.players:get(nil, data.user_id)
	if not target then return end

	-- Don't remove bot
	local bot = server:getBot()
	if bot and target.id == bot.id then return end

	-- Persist to database
	if server.friends_repo then
		server.friends_repo:removeFriend(player.id, target.id)
	end
end

return FriendRemove
