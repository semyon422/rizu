--- Packet 73: FRIEND_ADD
--- Player adds another player as a friend.

local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Friend add handler data.
---@class bancho.handler.FriendAddData
---@field user_id integer

--- Packet 73: FRIEND_ADD
---@class bancho.handler.FriendAdd: bancho.handler.IPacketHandler
---@operator call: bancho.handler.FriendAdd
local FriendAdd = IPacketHandler + {}

---@return bancho.handler.FriendAddData
function FriendAdd:parse(reader, bodyLen)
	return { user_id = reader:readI32() }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.FriendAddData
function FriendAdd:handle(server, player, data)
	local target = server.players:get(nil, data.user_id)
	if not target then return end

	-- Don't add bot as friend
	local bot = server:getBot()
	if bot and target.id == bot.id then return end

	-- Remove from blocks if present
	for i = 1, #player.blocks do
		if player.blocks[i] == target.id then
			table.remove(player.blocks, i)
			break
		end
	end

	-- Add to friends if not already present
	if server.friends_repo and server.friends_repo:isFriend(player.id, target.id) then
		return -- Already friends
	end

	-- Persist to database
	if server.friends_repo then
		server.friends_repo:addFriend(player.id, target.id)
	end

	-- Send friend presence
	local target_mode = target.status.mode:asVanilla()
	local target_stats = server.stats_repo and server.stats_repo:getStats(target.id, target_mode) or {}
	local presencePkt = ServerPackets.userPresence(
		target.id,
		target.name,
		0, -- utc_offset (TODO: load from DB)
		0, -- country_code (TODO: geo)
		target:bancho_priv(),
		target_mode,
		0, -- longitude (TODO: geo)
		0, -- latitude (TODO: geo)
		target_stats.rank or 0
	)
	player:enqueue(presencePkt)
end

return FriendAdd
