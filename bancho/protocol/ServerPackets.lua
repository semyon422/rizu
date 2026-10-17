local Binary = require("bancho.protocol.Binary")
local PacketWriter = require("bancho.protocol.PacketWriter")
local ComplexTypes = require("bancho.protocol.ComplexTypes")

--- Server-side packet constructors for Bancho protocol.
---@class bancho.protocol.ServerPackets
local M = {}

-- Packet ID constants
M.USER_ID                    = 5
M.SEND_MESSAGE               = 7
M.PONG                       = 8
M.USER_STATS                 = 11
M.USER_LOGOUT                = 12
M.SPECTATOR_JOINED           = 13
M.SPECTATOR_LEFT             = 14
M.SPECTATE_FRAMES            = 15
M.VERSION_UPDATE             = 19
M.SPECTATOR_CANT_SPECTATE    = 22
M.GET_ATTENTION              = 23
M.NOTIFICATION               = 24
M.UPDATE_MATCH               = 26
M.NEW_MATCH                  = 27
M.DISPOSE_MATCH              = 28
M.MATCH_JOIN_SUCCESS         = 36
M.MATCH_JOIN_FAIL            = 37
M.FELLOW_SPECTATOR_JOINED    = 42
M.FELLOW_SPECTATOR_LEFT      = 43
M.ALL_PLAYERS_LOADED         = 45
M.MATCH_START                = 46
M.MATCH_SCORE_UPDATE         = 48
M.MATCH_TRANSFER_HOST        = 50
M.MATCH_ALL_PLAYERS_LOADED   = 53
M.MATCH_PLAYER_FAILED        = 57
M.MATCH_COMPLETE             = 58
M.MATCH_SKIP                 = 61
M.RESTART_SERVER             = 62
M.CHANNEL_JOIN_SUCCESS       = 64
M.CHANNEL_INFO               = 65
M.CHANNEL_KICK               = 66
M.CHANNEL_AUTO_JOIN          = 67
M.PRIVILEGES                 = 71
M.FRIENDS_LIST               = 72
M.PROTOCOL_VERSION           = 75
M.MAIN_MENU_ICON             = 76
M.MATCH_PLAYER_SKIPPED       = 81
M.USER_PRESENCE              = 83
M.MATCH_INVITE               = 88
M.CHANNEL_INFO_END           = 89
M.MATCH_CHANGE_PASSWORD      = 91
M.SILENCE_END                = 92
M.USER_SILENCED              = 94
M.USER_DM_BLOCKED            = 100
M.TARGET_IS_SILENCED         = 101
M.VERSION_UPDATE_FORCED      = 102
M.SWITCH_SERVER              = 103
M.ACCOUNT_RESTRICTED         = 104
M.MATCH_ABORT                = 106
M.SWITCH_TOURNAMENT_SERVER   = 107

-- ---------------------------------------------------------------
-- Login / Session
-- ---------------------------------------------------------------

--- Build a login reply packet.
---@param user_id integer user ID (negative for failure)
---@return string
function M.loginReply(user_id)
	return Binary.writeHeader(M.USER_ID, 4) .. Binary.writeI32(user_id)
end

--- Build a protocol version packet.
---@param ver integer
---@return string
function M.protocolVersion(ver)
	return Binary.writeHeader(M.PROTOCOL_VERSION, 4) .. Binary.writeI32(ver)
end

--- Build a bancho privileges packet.
---@param priv integer
---@return string
function M.banchoPrivileges(priv)
	return Binary.writeHeader(M.PRIVILEGES, 4) .. Binary.writeI32(priv)
end

--- Build a restart server packet.
---@param delay_ms integer milliseconds until reconnection
---@return string
function M.restartServer(delay_ms)
	return Binary.writeHeader(M.RESTART_SERVER, 4) .. Binary.writeI32(delay_ms)
end

--- Build a version update packet.
---@return string
function M.versionUpdate()
	return Binary.writeHeader(M.VERSION_UPDATE, 0)
end

--- Build a version update forced packet.
---@return string
function M.versionUpdateForced()
	return Binary.writeHeader(M.VERSION_UPDATE_FORCED, 0)
end

--- Build a switch server packet.
---@param t integer
---@return string
function M.switchServer(t)
	return Binary.writeHeader(M.SWITCH_SERVER, 4) .. Binary.writeI32(t)
end

--- Build a switch tournament server packet.
---@param ip string
---@return string
function M.switchTournamentServer(ip)
	local w = PacketWriter()
	w:writeString(ip)
	return Binary.writeHeader(M.SWITCH_TOURNAMENT_SERVER, #w.body) .. w.body
end

--- Build an account restricted packet.
---@return string
function M.accountRestricted()
	return Binary.writeHeader(M.ACCOUNT_RESTRICTED, 0)
end

-- ---------------------------------------------------------------
-- Messaging
-- ---------------------------------------------------------------

--- Build a send message packet.
---@param sender string sender name
---@param msg string message text
---@param recipient string recipient name or channel
---@param sender_id integer sender user ID
---@return string
function M.sendMessage(sender, msg, recipient, sender_id)
	local body = ComplexTypes.writeMessage({sender = sender, text = msg, recipient = recipient, sender_id = sender_id})
	return Binary.writeHeader(M.SEND_MESSAGE, #body) .. body
end

--- Build a notification packet.
---@param msg string notification text
---@return string
function M.notification(msg)
	local w = PacketWriter()
	w:writeString(msg)
	return Binary.writeHeader(M.NOTIFICATION, #w.body) .. w.body
end

--- Build a get attention packet.
---@return string
function M.getAttention()
	return Binary.writeHeader(M.GET_ATTENTION, 0)
end

--- Build a user DM blocked packet.
---@param target string target name
---@return string
function M.userDmBlocked(target)
	local body = ComplexTypes.writeMessage({sender = "", text = "", recipient = target, sender_id = 0})
	return Binary.writeHeader(M.USER_DM_BLOCKED, #body) .. body
end

--- Build a target is silenced packet.
---@param target string target name
---@return string
function M.targetSilenced(target)
	local body = ComplexTypes.writeMessage({sender = "", text = "", recipient = target, sender_id = 0})
	return Binary.writeHeader(M.TARGET_IS_SILENCED, #body) .. body
end

-- ---------------------------------------------------------------
-- User Status / Presence
-- ---------------------------------------------------------------

--- Build a user stats packet.
---@param user_id integer
---@param action integer
---@param info_text string
---@param map_md5 string
---@param mods integer
---@param mode integer
---@param map_id integer
---@param ranked_score integer
---@param accuracy number
---@param plays integer
---@param total_score integer
---@param global_rank integer
---@param pp integer
---@return string
function M.userStats(user_id, action, info_text, map_md5, mods, mode, map_id, ranked_score, accuracy, plays, total_score, global_rank, pp)
	if pp > 0xFFFF then
		ranked_score = pp
		pp = 0
	end
	if accuracy > 1 then
		accuracy = accuracy / 100
	end
	local w = PacketWriter()
	w:writeI32(user_id)
	w:writeU8(action)
	w:writeString(info_text)
	w:writeString(map_md5)
	w:writeI32(mods)
	w:writeU8(mode)
	w:writeI32(map_id)
	w:writeI64(ranked_score)
	w:writeF32(accuracy)
	w:writeI32(plays)
	w:writeI64(total_score)
	w:writeI32(global_rank)
	w:writeU16(pp)
	return Binary.writeHeader(M.USER_STATS, #w.body) .. w.body
end

--- Build a user presence packet.
---@param user_id integer
---@param name string
---@param utc_offset integer
---@param country_code integer
---@param bancho_privileges integer
---@param mode integer
---@param longitude number
---@param latitude number
---@param global_rank integer
---@return string
function M.userPresence(user_id, name, utc_offset, country_code, bancho_privileges, mode, longitude, latitude, global_rank)
	local w = PacketWriter()
	w:writeI32(user_id)
	w:writeString(name)
	w:writeU8(utc_offset + 24)
	w:writeU8(country_code)
	w:writeU8(bit.bor(bancho_privileges, bit.lshift(mode, 5)))
	w:writeF32(longitude)
	w:writeF32(latitude)
	w:writeI32(global_rank)
	return Binary.writeHeader(M.USER_PRESENCE, #w.body) .. w.body
end

--- Build a user logout packet.
---@param user_id integer
---@return string
function M.userLogout(user_id)
	local w = PacketWriter()
	w:writeI32(user_id)
	w:writeU8(0)
	return Binary.writeHeader(M.USER_LOGOUT, #w.body) .. w.body
end

--- Build a friends list packet.
---@param friends integer[]
---@return string
function M.friendsList(friends)
	local body = Binary.writeI32List(friends)
	return Binary.writeHeader(M.FRIENDS_LIST, #body) .. body
end

--- Build a user silenced packet.
---@param user_id integer
---@return string
function M.userSilenced(user_id)
	return Binary.writeHeader(M.USER_SILENCED, 4) .. Binary.writeI32(user_id)
end

--- Build a silence end packet.
---@param delta integer seconds remaining
---@return string
function M.silenceEnd(delta)
	return Binary.writeHeader(M.SILENCE_END, 4) .. Binary.writeI32(delta)
end

-- ---------------------------------------------------------------
-- Spectating
-- ---------------------------------------------------------------

--- Build a spectator joined packet.
---@param user_id integer
---@return string
function M.spectatorJoined(user_id)
	return Binary.writeHeader(M.SPECTATOR_JOINED, 4) .. Binary.writeI32(user_id)
end

--- Build a spectator left packet.
---@param user_id integer
---@return string
function M.spectatorLeft(user_id)
	return Binary.writeHeader(M.SPECTATOR_LEFT, 4) .. Binary.writeI32(user_id)
end

--- Build a spectate frames packet.
---@param data string raw frame data
---@return string
function M.spectateFrames(data)
	return Binary.writeHeader(M.SPECTATE_FRAMES, #data) .. data
end

--- Build a fellow spectator joined packet.
---@param user_id integer
---@return string
function M.fellowSpectatorJoined(user_id)
	return Binary.writeHeader(M.FELLOW_SPECTATOR_JOINED, 4) .. Binary.writeI32(user_id)
end

--- Build a fellow spectator left packet.
---@param user_id integer
---@return string
function M.fellowSpectatorLeft(user_id)
	return Binary.writeHeader(M.FELLOW_SPECTATOR_LEFT, 4) .. Binary.writeI32(user_id)
end

--- Build a spectator can't spectate packet.
---@param user_id integer
---@return string
function M.spectatorCantSpectate(user_id)
	return Binary.writeHeader(M.SPECTATOR_CANT_SPECTATE, 4) .. Binary.writeI32(user_id)
end

-- ---------------------------------------------------------------
-- Multiplayer Match
-- ---------------------------------------------------------------

--- Build an update match packet.
---@param m bancho.protocol.MultiplayerMatch
---@param send_pw? boolean
---@return string
function M.updateMatch(m, send_pw)
	local body = ComplexTypes.writeMatch(m, send_pw)
	return Binary.writeHeader(M.UPDATE_MATCH, #body) .. body
end

--- Build a new match packet.
---@param m bancho.protocol.MultiplayerMatch
---@return string
function M.newMatch(m)
	local body = ComplexTypes.writeMatch(m, true)
	return Binary.writeHeader(M.NEW_MATCH, #body) .. body
end

--- Build a match start packet.
---@param m bancho.protocol.MultiplayerMatch
---@return string
function M.matchStart(m)
	local body = ComplexTypes.writeMatch(m, true)
	return Binary.writeHeader(M.MATCH_START, #body) .. body
end

--- Build a match join success packet.
---@param m bancho.protocol.MultiplayerMatch
---@return string
function M.matchJoinSuccess(m)
	local body = ComplexTypes.writeMatch(m, true)
	return Binary.writeHeader(M.MATCH_JOIN_SUCCESS, #body) .. body
end

--- Build a match join fail packet.
---@return string
function M.matchJoinFail()
	return Binary.writeHeader(M.MATCH_JOIN_FAIL, 0)
end

--- Build a dispose match packet.
---@param id integer
---@return string
function M.disposeMatch(id)
	return Binary.writeHeader(M.DISPOSE_MATCH, 4) .. Binary.writeI32(id)
end

--- Build a match score update packet.
---@param sf bancho.protocol.ScoreFrame
---@return string
function M.matchScoreUpdate(sf)
	local body = ComplexTypes.writeScoreFrame(sf)
	return Binary.writeHeader(M.MATCH_SCORE_UPDATE, #body) .. body
end

--- Build a match complete packet.
---@return string
function M.matchComplete()
	return Binary.writeHeader(M.MATCH_COMPLETE, 0)
end

--- Build a match transfer host packet.
---@return string
function M.matchTransferHost()
	return Binary.writeHeader(M.MATCH_TRANSFER_HOST, 0)
end

--- Build a match all players loaded packet.
---@return string
function M.matchAllPlayersLoaded()
	return Binary.writeHeader(M.MATCH_ALL_PLAYERS_LOADED, 0)
end

--- Build a match player failed packet.
---@param slot_id integer
---@return string
function M.matchPlayerFailed(slot_id)
	return Binary.writeHeader(M.MATCH_PLAYER_FAILED, 4) .. Binary.writeI32(slot_id)
end

--- Build a match skip packet.
---@return string
function M.matchSkip()
	return Binary.writeHeader(M.MATCH_SKIP, 0)
end

--- Build a match player skipped packet.
---@param user_id integer
---@return string
function M.matchPlayerSkipped(user_id)
	return Binary.writeHeader(M.MATCH_PLAYER_SKIPPED, 4) .. Binary.writeI32(user_id)
end

--- Build a match abort packet.
---@return string
function M.matchAbort()
	return Binary.writeHeader(M.MATCH_ABORT, 0)
end

--- Build a match change password packet.
---@param new_password string
---@return string
function M.matchChangePassword(new_password)
	local w = PacketWriter()
	w:writeString(new_password)
	return Binary.writeHeader(M.MATCH_CHANGE_PASSWORD, #w.body) .. w.body
end

--- Build a match invite packet.
---@param sender string sender name
---@param msg string invite message
---@param target string target name
---@param sender_id integer sender ID
---@return string
function M.matchInvite(sender, msg, target, sender_id)
	local body = ComplexTypes.writeMessage({sender = sender, text = msg, recipient = target, sender_id = sender_id})
	return Binary.writeHeader(M.MATCH_INVITE, #body) .. body
end

-- ---------------------------------------------------------------
-- Channels
-- ---------------------------------------------------------------

--- Build a channel join success packet.
---@param name string
---@return string
function M.channelJoin(name)
	local w = PacketWriter()
	w:writeString(name)
	return Binary.writeHeader(M.CHANNEL_JOIN_SUCCESS, #w.body) .. w.body
end

--- Build a channel info packet.
---@param name string
---@param topic string
---@param p_count integer
---@return string
function M.channelInfo(name, topic, p_count)
	local body = ComplexTypes.writeChannel({name = name, topic = topic, players = p_count})
	return Binary.writeHeader(M.CHANNEL_INFO, #body) .. body
end

--- Build a channel kick packet.
---@param name string
---@return string
function M.channelKick(name)
	local w = PacketWriter()
	w:writeString(name)
	return Binary.writeHeader(M.CHANNEL_KICK, #w.body) .. w.body
end

--- Build a channel info end packet.
---@return string
function M.channelInfoEnd()
	return Binary.writeHeader(M.CHANNEL_INFO_END, 0)
end

--- Build a channel auto-join packet.
---@param name string
---@param topic string
---@param p_count integer
---@return string
function M.channelAutoJoin(name, topic, p_count)
	local body = ComplexTypes.writeChannel({name = name, topic = topic, players = p_count})
	return Binary.writeHeader(M.CHANNEL_AUTO_JOIN, #body) .. body
end

--- Build a pong packet.
---@return string
function M.pong()
	return Binary.writeHeader(M.PONG, 0)
end

--- Build a main menu icon packet.
---@param icon_url string
---@param onclick_url string
---@return string
function M.mainMenuIcon(icon_url, onclick_url)
	local w = PacketWriter()
	w:writeString(icon_url .. "|" .. onclick_url)
	return Binary.writeHeader(M.MAIN_MENU_ICON, #w.body) .. w.body
end

return M
