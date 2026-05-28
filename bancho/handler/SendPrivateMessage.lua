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
	local msg = data.text:gsub("^%s*(.-)%s*$", "")
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

	-- Check if target has PMs restricted to friends
	if target.pm_private and #target.friends > 0 then
		local isFriend = false
		for _, friendId in ipairs(target.friends) do
			if friendId == player.id then
				isFriend = true
				break
			end
		end
		if not isFriend then
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
	if target.status.action == Action.AFK and target.away_msg then
		-- TODO: send away message as private message
		return
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
					player:enqueue(respPkt)
				end
				return
			end
		end

		-- Normal PM
		local pkt = ServerPackets.sendMessage(player.name, msg, targetName, player.id)
		target:enqueue(pkt)
	else
		-- TODO: mail system — store for offline delivery
		player:enqueue(ServerPackets.notification(targetName .. " is currently offline, but will receive your message on their next login."))
	end
end

return SendPrivateMessage
