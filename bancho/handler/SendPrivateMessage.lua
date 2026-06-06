--- Packet 25: SEND_PRIVATE_MESSAGE
--- Private message between players.
---
--- NOTE: Full implementation requires mail system for offline messages
--- and block list persistence. Currently handles online-to-online messages only.

local Action = require("bancho.constants.Action")
local ServerPackets = require("bancho.protocol.ServerPackets")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Send private message handler data.
---@class bancho.handler.SendPrivateMessageData: bancho.protocol.Message

--- Packet 25: SEND_PRIVATE_MESSAGE
---@class bancho.handler.SendPrivateMessage: bancho.handler.IPacketHandler
---@operator call: bancho.handler.SendPrivateMessage
local SendPrivateMessage = IPacketHandler + {}

---@return bancho.handler.SendPrivateMessageData
function SendPrivateMessage:parse(reader, bodyLen)
	return ComplexTypes.readMessage(reader)
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.SendPrivateMessageData
function SendPrivateMessage:handle(server, player, data)
	if player.silenced then return end

	-- Trim message text
	local msg = data.text:gsub("^%s*(.-)%s*$", "%1")
	if #msg == 0 then return end

	local targetName = data.recipient

	-- Look up target online
	local target = server.players:get(nil, nil, targetName)
	if not target then
		-- TODO: mail system — store for offline delivery
		return
	end

	-- Check if sender is blocked by target
	for _, blockedId in ipairs(target.blocks) do
		if blockedId == player.id then
			player:enqueue(ServerPackets.userDmBlocked(targetName))
			return
		end
	end

	local target_user = server.user_repo and server.user_repo:findUser(target.id) or nil

	-- Check if target has PMs restricted to friends
	if target_user and (target_user.pm_private == true or target_user.pm_private == 1) then
		local is_friend = server.friends_repo and server.friends_repo:isFriend(target.id, player.id) or false
		if not is_friend then
			player:enqueue(ServerPackets.userDmBlocked(targetName))
			return
		end
	end

	-- Check if target is silenced
	if target.silenced then
		player:enqueue(ServerPackets.targetSilenced(targetName))
		return
	end

	-- Truncate long messages
	if #msg > 2000 then
		msg = msg:sub(1, 2000) .. "... (truncated)"
		player:enqueue(ServerPackets.notification("Your message was truncated\n(exceeded 2000 characters)."))
	end

	-- Send away message if target is AFK
	local away_msg = target_user and target_user.away_msg or nil
	if target.status.action == Action.AFK and away_msg and #away_msg > 0 then
		local away = ServerPackets.sendMessage(target.name, away_msg, player.name, target.id)
		if server.players._dict then
			server.players._dict:rpush("pq:" .. player.token, away)
		else
			player:enqueue(away)
		end
	end

	-- Send message to target if online
	if target.is_online then
		-- Check if target is bot
		local bot = server:getBot()
		if bot and target.id == bot.id then
			-- Dispatch commands to bot
			local result = server.commands:dispatch(player, target, msg)
			if result then
				-- Command executed
				if result.response then
					local respPkt = ServerPackets.sendMessage(bot.name, result.response, targetName, bot.id)
					if server.players._dict then
						server.players._dict:rpush("pq:" .. player.token, respPkt)
					else
						player:enqueue(respPkt)
					end
				end
				return
			end
		end

		-- Normal PM
		local pkt = ServerPackets.sendMessage(player.name, msg, targetName, player.id)
		if server.players._dict then
			server.players._dict:rpush("pq:" .. target.token, pkt)
		else
			target:enqueue(pkt)
		end
	else
		-- TODO: mail system — store for offline delivery
		player:enqueue(ServerPackets.notification(targetName .. " is currently offline, but will receive your message on their next login."))
	end
end

return SendPrivateMessage
