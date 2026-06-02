--- Packet 1: SEND_PUBLIC_MESSAGE
--- Client sends a message to a channel or special recipient (#spectator, #multiplayer).

local ComplexTypes = require("bancho.protocol.ComplexTypes")
local ServerPackets = require("bancho.protocol.ServerPackets")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Channels to ignore.
local IGNORED_CHANNELS = {
	["#highlight"] = true,
	["#userlog"] = true,
}

--- Packet 1: SEND_PUBLIC_MESSAGE
---@class bancho.handler.SendPublicMessage: bancho.handler.IPacketHandler
---@operator call: bancho.handler.SendPublicMessage
local SendPublicMessage = IPacketHandler + {}

---@return bancho.protocol.Message
function SendPublicMessage:parse(reader, bodyLen)
	return {
		recipient = reader:readString(),
		text = reader:readString(),
	}
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.protocol.Message
function SendPublicMessage:handle(server, player, data)
	if player.silenced then return end

	local text = data.text:gsub("^%s*(.-)%s*$", "%1")
	if #text == 0 then return end

	local recipient = data.recipient

	-- Ignore special channels
	if IGNORED_CHANNELS[recipient] then return end

	-- Resolve target channel
	local target_channel

	if recipient == "#spectator" then
		-- Spectator channel
		local spec_id
		if player.spectating then
			spec_id = player.spectating.id
		elseif #player.spectators > 0 then
			spec_id = player.id
		else
			return
		end
		target_channel = server.channels:get("#spec_" .. spec_id)
	elseif recipient == "#multiplayer" then
		-- Multiplayer match channel
		if not player.match then return end
		target_channel = player.match.chat
	else
		target_channel = server.channels:get(recipient)
	end

	if not target_channel then return end
	if not target_channel:contains(player) then return end
	if not target_channel:canWrite(player.priv) then return end

	-- Check for command
	local result = server.commands:dispatch(player, target_channel, text)
	if result then
		-- Command executed
		if result.response then
			-- Send response to channel members
			local respPkt = ServerPackets.sendMessage(server.config.bot_name, result.response, target_channel.name, server.config.bot_id)
			for _, p in pairs(target_channel.players) do
				p:enqueue(respPkt)
			end
		end
		return
	end

	-- Not a command — send as normal message
	-- Truncate long messages
	if #text > 2000 then
		text = text:sub(1, 2000) .. "... (truncated)"
		player:enqueue(ServerPackets.notification("Your message was truncated\n(exceeded 2000 characters)."))
	end

	-- Send message to all channel members
	local msg = ServerPackets.sendMessage(player.name, text, target_channel.name, player.id)

	-- Build immune list (just the sender)
	local immune = {player}

	-- Use PlayerCollection:enqueue for dict-backed collections
	-- This ensures messages persist across requests via dict pq
	local function broadcast(targetPlayers)
		if server.players._dict then
			-- For dict-backed collections, use the dict pq
			for _, p in pairs(targetPlayers) do
				if p.id ~= player.id then
					server.players._dict:rpush("pq:" .. p.token, msg)
				end
			end
		else
			for _, p in pairs(targetPlayers) do
				if p.id ~= player.id then
					p:enqueue(msg)
				end
			end
		end
	end

	broadcast(target_channel.players)
end

return SendPublicMessage
