--- Packet 31: CREATE_MATCH
--- Client creates a new multiplayer match.

local ComplexTypes = require("bancho.protocol.ComplexTypes")
local ServerPackets = require("bancho.protocol.ServerPackets")
local Channel = require("bancho.model.Channel")
local GameMode = require("bancho.constants.GameMode")
local SlotStatus = require("bancho.constants.SlotStatus")
local IPacketHandler = require("bancho.handler.IPacketHandler")

--- Create match handler data.
---@class bancho.handler.CreateMatchData
---@field match_data bancho.protocol.MultiplayerMatch

--- Packet 31: CREATE_MATCH
---@class bancho.handler.CreateMatch: bancho.handler.IPacketHandler
---@operator call: bancho.handler.CreateMatch
local CreateMatch = IPacketHandler + {}

---@return bancho.handler.CreateMatchData
function CreateMatch:parse(reader, bodyLen)
	return { match_data = ComplexTypes.readMatch(reader) }
end

---@param server bancho.server.BanchoServer
---@param player bancho.model.Player
---@param data bancho.handler.CreateMatchData
function CreateMatch:handle(server, player, data)
	local m = data.match_data

	-- Validate: host must be the player
	if m.host_id ~= player.id then return end

	-- Restricted/silenced players can't create matches
	if player.restricted or player.silenced then
		player:enqueue(
			ServerPackets.matchJoinFail() ..
			ServerPackets.notification("Multiplayer is not available while restricted.")
		)
		return
	end

	-- Create match via manager
	local match = server.match_manager:create(
		m.name,
		m.passwd,
		player.id,
		GameMode.fromValue(m.mode),
		m.mods,
		m.win_condition,
		m.team_type,
		m.freemods
	)

	if not match then
		player:enqueue(ServerPackets.notification("Failed to create match (no slots available).")
			.. ServerPackets.matchJoinFail())
		return
	end

	-- Preserve client-provided open/locked layout for room size.
	for i = 1, 16 do
		local idx = i - 1
		local status = m.slot_statuses[i]
		if status == SlotStatus.OPEN or status == SlotStatus.LOCKED then
			match.slots[idx].status = status
		end
		match.slots[idx].team = m.slot_teams[i]
	end

	-- Set map info
	match.map_id = m.map_id
	match.map_md5 = m.map_md5
	match.map_name = m.map_name

	-- Create match chat channel
	local chat_channel = Channel(
		"#multi_" .. match.id,
		"MID " .. match.id .. "'s multiplayer channel.",
		0, 0, false, true
	)
	server.channels:add(chat_channel)
	match.chat = chat_channel

	-- Add player to match (host occupies slot 0 in a fresh match)
	if not server.match_manager:addPlayer(match, player) then
		server.match_manager:dispose(match.id)
		player:enqueue(ServerPackets.matchJoinFail())
		return
	end

	-- Send join success
	local match_data = server.match_manager:buildMatchData(match)
	player:enqueue(ServerPackets.matchJoinSuccess(match_data))

	-- Set player's match reference
	player.match = match

	-- Broadcast match state to lobby and match participants
	server.chat_manager:notifyMatchUpdate(match, match_data, server.channels, true)

	-- Bot message in match channel
	server.chat_manager:sendBot(chat_channel, "Match created by " .. player.name .. ".")
end

return CreateMatch
