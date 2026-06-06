--- Bancho protocol client.
---
--- High-level client for interacting with a bancho server.
--- Handles connection lifecycle, login, packet exchange, and event emission.
---
--- Usage:
---   local client = BanchoClient(ClientConfig {
---       host = "c.localhost",
---       port = 8180,
---       username = "test",
---       password_md5 = "md5hash",
---   })
---
---   local packets, err = client:login()
---   if err then error(err) end
---
---   -- Process login response packets
---   for _, pkt in ipairs(packets) do
---       if pkt.id == 5 then -- USER_ID
---           local user_id = Binary.readI32(pkt.body, 1)
---           print("Logged in as user", user_id)
---       end
---   end

local ClientConfig = require("bancho.client.ClientConfig")
local HttpTransport = require("bancho.client.HttpTransport")
local Binary = require("bancho.protocol.Binary")
local PacketWriter = require("bancho.protocol.PacketWriter")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local ClientPackets = require("bancho.protocol.ClientPackets")
local ServerPackets = require("bancho.protocol.ServerPackets")
local SlotStatus = require("bancho.constants.SlotStatus")

local class = require("class")

--- Login result with user ID.
---@class bancho.client.LoginResult
---@field success boolean
---@field user_id integer User ID (negative on failure)
---@field packets bancho.client.IncomingPacket[] All login response packets
---@field error string? Error message on failure

--- Client state.
---@class bancho.client.BanchoClient
---@operator call: bancho.client.BanchoClient
---@field config bancho.client.ClientConfig
---@field transport bancho.client.HttpTransport
---@field user_id integer? Current user ID (set after login)
---@field logged_in boolean Whether the client is logged in
local BanchoClient = class()

---@param config bancho.client.ClientConfig
function BanchoClient:new(config)
	self.config = config
	self.transport = HttpTransport(config)
	self.logged_in = false
	return self
end

--- Login to the server.
--- Returns parsed login result with user ID and all response packets.
---@return bancho.client.LoginResult
function BanchoClient:login()
	local packets, err = self.transport:login_and_parse()
	if err then
		return { success = false, user_id = -1, packets = {}, error = err }
	end

	-- Find USER_ID packet (id=5)
	local user_id = -1
	for _, pkt in ipairs(packets) do
		if pkt.id == ServerPackets.USER_ID then
			user_id = Binary.readI32(pkt.body, 1)
			break
		end
	end

	self.logged_in = user_id > 0
	self.user_id = user_id > 0 and user_id or nil

	return {
		success = user_id > 0,
		user_id = user_id,
		packets = packets,
		error = user_id <= 0 and "login failed (user_id=" .. user_id .. ")" or nil,
	}
end

--- Send binary packet data to the server.
--- Requires a successful login first.
---@param data string Binary packet data
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:send(data)
	if not self.logged_in then
		return {}, "not logged in"
	end
	return self.transport:send_and_parse(data)
end

--- Build a client packet with header.
---@param id integer Packet ID
---@param body string Body bytes
---@return string
function BanchoClient:build_packet(id, body)
	return Binary.writeHeader(id, #body) .. body
end

--- Send a chat message to a channel or user.
---@param recipient string Channel name (#general) or username
---@param message string Message text
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:send_message(recipient, message)
	local body = ComplexTypes.writeMessage({
		sender = self.config.username or "",
		text = message,
		recipient = recipient,
		sender_id = self.user_id or 0,
	})
	return self:send(self:build_packet(ClientPackets.SEND_PUBLIC_MESSAGE, body))
end

--- Send a private message to a user.
---@param target string Username
---@param message string Message text
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:send_private_message(target, message)
	local body = ComplexTypes.writeMessage({
		sender = self.config.username or "",
		text = message,
		recipient = target,
		sender_id = self.user_id or 0,
	})
	return self:send(self:build_packet(ClientPackets.SEND_PRIVATE_MESSAGE, body))
end

--- Join a chat channel.
---@param name string Channel name
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:join_channel(name)
	local w = PacketWriter()
	w:writeString(name)
	return self:send(self:build_packet(ClientPackets.CHANNEL_JOIN, w.body))
end

--- Leave a chat channel.
---@param name string Channel name
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:part_channel(name)
	local w = PacketWriter()
	w:writeString(name)
	return self:send(self:build_packet(ClientPackets.CHANNEL_PART, w.body))
end

--- Create a multiplayer match.
---@param name string Match name
---@param password string? Match password (empty for public)
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:create_match(name, password)
	password = password or ""
	local w = PacketWriter()
	-- Build a minimal match structure matching ComplexTypes.readMatch
	w:writeI16(0) -- match id (server will assign)
	w:writeI8(0) -- in_progress
	w:writeI8(0) -- powerplay
	w:writeI32(0) -- mods
	w:writeString(name) -- name
	w:writeString(password) -- password
	w:writeString("") -- map_name
	w:writeI32(0) -- map_id
	w:writeString("") -- map_md5
	for _ = 1, 16 do w:writeI8(SlotStatus.OPEN) end -- slot_statuses
	for _ = 1, 16 do w:writeI8(0) end -- slot_teams
	-- No slot_ids needed (all slots empty)
	w:writeI32(self.user_id) -- host_id
	w:writeI8(0) -- mode (osu!)
	w:writeI8(0) -- win_condition
	w:writeI8(0) -- team_type (head-to-head)
	w:writeI8(0) -- freemods (false)
	w:writeI32(0) -- seed
	return self:send(self:build_packet(ClientPackets.CREATE_MATCH, w.body))
end

--- Join a multiplayer match.
---@param match_id integer Match ID
---@param password string? Match password
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:join_match(match_id, password)
	password = password or ""
	local w = PacketWriter()
	w:writeI32(match_id)
	w:writeString(password)
	return self:send(self:build_packet(ClientPackets.JOIN_MATCH, w.body))
end

--- Leave current multiplayer match.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:part_match()
	return self:send(self:build_packet(ClientPackets.PART_MATCH, ""))
end

--- Join the multiplayer lobby.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:join_lobby()
	return self:send(self:build_packet(ClientPackets.JOIN_LOBBY, ""))
end

--- Leave the multiplayer lobby.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:part_lobby()
	return self:send(self:build_packet(ClientPackets.PART_LOBBY, ""))
end

--- Send a ping packet.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:ping()
	return self:send(self:build_packet(ClientPackets.PING, ""))
end

--- Update player status/action.
--- Format: mode\0info_text\0map_md5\0mods\0action\0map_id
---@param mode integer Game mode (0=osu, 1=taiko, 2=ctb, 3=mania)
---@param action integer Action ID
---@param info_text string Status text
---@param map_md5 string Beatmap MD5
---@param mods integer Mods bitmask
---@param map_id integer Beatmap ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:update_status(mode, action, info_text, map_md5, mods, map_id)
	local w = PacketWriter()
	w:writeU8(mode)
	w:writeString(info_text)
	w:writeString(map_md5)
	w:writeI32(mods)
	w:writeU8(action)
	w:writeI32(map_id)
	return self:send(self:build_packet(ClientPackets.REQUEST_STATUS_UPDATE, w.body))
end

--- Start spectating a player.
---@param user_id integer Target user ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:start_spectating(user_id)
	local w = PacketWriter()
	w:writeI32(user_id)
	return self:send(self:build_packet(ClientPackets.START_SPECTATING, w.body))
end

--- Stop spectating.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:stop_spectating()
	return self:send(self:build_packet(ClientPackets.STOP_SPECTATING, ""))
end

--- Set away message.
---@param message string? Away message (nil to clear)
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:set_away_message(message)
	message = message or ""
	local body = ComplexTypes.writeMessage({
		sender = self.config.username or "",
		text = message,
		recipient = "",
		sender_id = self.user_id or 0,
	})
	return self:send(self:build_packet(ClientPackets.SET_AWAY_MESSAGE, body))
end

--- Request user stats for a specific user.
---@param user_id integer Target user ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:request_user_stats(user_id)
	local w = PacketWriter()
	w:writeU16(1) -- list length
	w:writeI32(user_id)
	return self:send(self:build_packet(ClientPackets.USER_STATS_REQUEST, w.body))
end

--- Request user presence for a specific user.
---@param user_id integer Target user ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:request_user_presence(user_id)
	return self:send(self:build_packet(ClientPackets.USER_PRESENCE_REQUEST, Binary.writeI32List({user_id})))
end

--- Request presence of all online users.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:request_all_presences()
	return self:send(self:build_packet(ClientPackets.USER_PRESENCE_REQUEST_ALL, ""))
end

--- Toggle receiving presence updates.
---@param mode integer Game mode to receive updates for
---@param enabled boolean True to receive, false to stop
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:receive_updates(mode, enabled)
	local w = PacketWriter()
	w:writeU8(mode)
	w:writeU8(enabled and 1 or 0)
	return self:send(self:build_packet(ClientPackets.RECEIVE_UPDATES, w.body))
end

--- Add a friend.
---@param user_id integer Friend user ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:add_friend(user_id)
	return self:send(self:build_packet(ClientPackets.FRIEND_ADD, Binary.writeI32(user_id)))
end

--- Remove a friend.
---@param user_id integer Friend user ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:remove_friend(user_id)
	return self:send(self:build_packet(ClientPackets.FRIEND_REMOVE, Binary.writeI32(user_id)))
end

--- Toggle blocking non-friend DMs.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:toggle_block_dms()
	return self:send(self:build_packet(ClientPackets.TOGGLE_BLOCK_NON_FRIEND_DMS, ""))
end

--- Match: ready up.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_ready()
	return self:send(self:build_packet(ClientPackets.MATCH_READY, ""))
end

--- Match: lock/unlock the match.
---@param locked boolean True to lock, false to unlock
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_lock(locked)
	-- Match lock sends slot ID (I32) to lock/unlock
	-- Use slot 0 as default (host slot)
	local w = PacketWriter()
	w:writeI32(0)
	return self:send(self:build_packet(ClientPackets.MATCH_LOCK, w.body))
end

--- Match: start the match.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_start()
	return self:send(self:build_packet(ClientPackets.MATCH_START, ""))
end

--- Match: request skip.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_skip()
	return self:send(self:build_packet(ClientPackets.MATCH_SKIP_REQUEST, ""))
end

--- Match: transfer host.
---@param slot_id integer Target slot ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_transfer_host(slot_id)
	local w = PacketWriter()
	w:writeI32(slot_id)
	return self:send(self:build_packet(ClientPackets.MATCH_TRANSFER_HOST, w.body))
end

--- Match: change mods.
---@param mods integer Mods bitmask
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_change_mods(mods)
	local w = PacketWriter()
	w:writeI32(mods)
	return self:send(self:build_packet(ClientPackets.MATCH_CHANGE_MODS, w.body))
end

--- Match: change team.
---@param team integer Team ID (0=neutral, 1=team 1, 2=team 2)
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_change_team(team)
	local w = PacketWriter()
	w:writeU8(team)
	return self:send(self:build_packet(ClientPackets.MATCH_CHANGE_TEAM, w.body))
end

--- Match: change password.
---@param password string New password
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_change_password(password)
	local w = PacketWriter()
	w:writeString(password)
	return self:send(self:build_packet(ClientPackets.MATCH_CHANGE_PASSWORD, w.body))
end

--- Match: signal load complete.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_load_complete()
	return self:send(self:build_packet(ClientPackets.MATCH_LOAD_COMPLETE, ""))
end

--- Match: signal no beatmap.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_no_beatmap()
	return self:send(self:build_packet(ClientPackets.MATCH_NO_BEATMAP, ""))
end

--- Match: signal has beatmap.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_has_beatmap()
	return self:send(self:build_packet(ClientPackets.MATCH_HAS_BEATMAP, ""))
end

--- Match: signal failed.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_failed()
	return self:send(self:build_packet(ClientPackets.MATCH_FAILED, ""))
end

--- Match: signal complete.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_complete()
	return self:send(self:build_packet(ClientPackets.MATCH_COMPLETE, ""))
end

--- Match: invite a user.
---@param username string User to invite
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_invite(username)
	local w = PacketWriter()
	w:writeString(username)
	return self:send(self:build_packet(ClientPackets.MATCH_INVITE, w.body))
end

--- Match: change slot settings.
---@param slot_id integer Slot ID (0-15)
---@param status integer Slot status
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_change_slot(slot_id, status)
	local w = PacketWriter()
	w:writeU8(slot_id)
	w:writeU8(status)
	return self:send(self:build_packet(ClientPackets.MATCH_CHANGE_SLOT, w.body))
end

--- Match: change settings.
---@param map_id integer Beatmap ID
---@param map_md5 string Beatmap MD5
---@param mods integer Mods bitmask
---@param freemods boolean Free mods enabled
---@param win_condition integer Win condition
---@param team_type integer Team type
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_change_settings(map_id, map_md5, mods, freemods, win_condition, team_type)
	local w = PacketWriter()
	w:writeI32(map_id)
	w:writeString(map_md5)
	w:writeI32(mods)
	w:writeU8(freemods and 1 or 0)
	w:writeU8(win_condition)
	w:writeU8(team_type)
	return self:send(self:build_packet(ClientPackets.MATCH_CHANGE_SETTINGS, w.body))
end

--- Match: not ready.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:match_not_ready()
	return self:send(self:build_packet(ClientPackets.MATCH_NOT_READY, ""))
end

--- Change action.
---@param action integer Action ID
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:change_action(action)
	local w = PacketWriter()
	w:writeU8(action)
	return self:send(self:build_packet(ClientPackets.CHANGE_ACTION, w.body))
end

--- Logout.
---@return bancho.client.IncomingPacket[]
---@return string? error
function BanchoClient:logout()
	self.logged_in = false
	self.user_id = nil
	return self:send(self:build_packet(ClientPackets.LOGOUT, ""))
end

return BanchoClient
