local Binary = require("bancho.protocol.Binary")
local PacketWriter = require("bancho.protocol.PacketWriter")
local ComplexTypes = require("bancho.protocol.ComplexTypes")

local M = {}

M.USER_ID                    = 5
M.SEND_MESSAGE               = 7
M.PONG                       = 8
M.USER_STATS                 = 11
M.USER_LOGOUT                = 12
M.SPECTATOR_JOINED           = 13
M.SPECTATOR_LEFT             = 14
M.SPECTATE_FRAMES            = 15
M.NOTIFICATION               = 24
M.UPDATE_MATCH               = 26
M.NEW_MATCH                  = 27
M.DISPOSE_MATCH              = 28
M.MATCH_JOIN_SUCCESS         = 36
M.MATCH_JOIN_FAIL            = 37
M.FELLOW_SPECTATOR_JOINED    = 42
M.FELLOW_SPECTATOR_LEFT      = 43
M.MATCH_START                = 46
M.MATCH_SCORE_UPDATE         = 48
M.CHANNEL_JOIN_SUCCESS       = 64
M.CHANNEL_INFO               = 65
M.PRIVILEGES                 = 71
M.FRIENDS_LIST               = 72

function M.loginReply(user_id)
	return Binary.writeHeader(M.USER_ID, 4) .. Binary.writeI32(user_id)
end

function M.sendMessage(sender, msg, recipient, sender_id)
	local body = ComplexTypes.writeMessage({sender = sender, text = msg, recipient = recipient, sender_id = sender_id})
	return Binary.writeHeader(M.SEND_MESSAGE, #body) .. body
end

function M.pong()
	return Binary.writeHeader(M.PONG, 0)
end

function M.notification(msg)
	local w = PacketWriter()
	w:writeString(msg)
	return Binary.writeHeader(M.NOTIFICATION, #w.body) .. w.body
end

function M.userStats(user_id, action, info_text, map_md5, mods, mode, map_id, ranked_score, accuracy, plays, total_score, global_rank, pp)
	if pp > 0xFFFF then
		ranked_score = pp
		pp = 0
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

function M.userLogout(user_id)
	local w = PacketWriter()
	w:writeI32(user_id)
	w:writeU8(0)
	return Binary.writeHeader(M.USER_LOGOUT, #w.body) .. w.body
end

function M.spectatorJoined(user_id)
	return Binary.writeHeader(M.SPECTATOR_JOINED, 4) .. Binary.writeI32(user_id)
end

function M.spectatorLeft(user_id)
	return Binary.writeHeader(M.SPECTATOR_LEFT, 4) .. Binary.writeI32(user_id)
end

function M.spectateFrames(data)
	return Binary.writeHeader(M.SPECTATE_FRAMES, #data) .. data
end

function M.updateMatch(m, send_pw)
	local body = ComplexTypes.writeMatch(m, send_pw)
	return Binary.writeHeader(M.UPDATE_MATCH, #body) .. body
end

function M.matchJoinSuccess(m)
	local body = ComplexTypes.writeMatch(m, true)
	return Binary.writeHeader(M.MATCH_JOIN_SUCCESS, #body) .. body
end

function M.matchJoinFail()
	return Binary.writeHeader(M.MATCH_JOIN_FAIL, 0)
end

function M.disposeMatch(id)
	return Binary.writeHeader(M.DISPOSE_MATCH, 4) .. Binary.writeI32(id)
end

function M.channelJoin(name)
	local w = PacketWriter()
	w:writeString(name)
	return Binary.writeHeader(M.CHANNEL_JOIN_SUCCESS, #w.body) .. w.body
end

function M.channelInfo(name, topic, p_count)
	local body = ComplexTypes.writeChannel({name = name, topic = topic, players = p_count})
	return Binary.writeHeader(M.CHANNEL_INFO, #body) .. body
end

function M.banchoPrivileges(priv)
	return Binary.writeHeader(M.PRIVILEGES, 4) .. Binary.writeI32(priv)
end

function M.friendsList(friends)
	local body = Binary.writeI32List(friends)
	return Binary.writeHeader(M.FRIENDS_LIST, #body) .. body
end


M.USER_PRESENCE              = 83
M.MATCH_SCORE_UPDATE         = 48
M.MATCH_COMPLETE             = 58
M.CHANNEL_KICK               = 66

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

function M.matchScoreUpdate(sf)
	local body = ComplexTypes.writeScoreFrame(sf)
	return Binary.writeHeader(M.MATCH_SCORE_UPDATE, #body) .. body
end

function M.matchComplete()
	return Binary.writeHeader(M.MATCH_COMPLETE, 0)
end

function M.channelKick(name)
	local w = PacketWriter()
	w:writeString(name)
	return Binary.writeHeader(M.CHANNEL_KICK, #w.body) .. w.body
end

function M.protocolVersion(ver)
	return Binary.writeHeader(M.PROTOCOL_VERSION, 4) .. Binary.writeI32(ver)
end

M.PROTOCOL_VERSION = 75
M.CHANNEL_INFO_END = 89
M.CHANNEL_AUTO_JOIN = 67

function M.channelInfoEnd()
	return Binary.writeHeader(M.CHANNEL_INFO_END, 0)
end

function M.channelAutoJoin(name, topic, p_count)
	local body = ComplexTypes.writeChannel({name = name, topic = topic, players = p_count})
	return Binary.writeHeader(M.CHANNEL_AUTO_JOIN, #body) .. body
end
return M
