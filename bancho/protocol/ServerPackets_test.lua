--- Tests for bancho protocol ServerPackets constructors.

local ServerPackets = require("bancho.protocol.ServerPackets")
local Binary = require("bancho.protocol.Binary")
local PacketReader = require("bancho.protocol.PacketReader")

local test = {}

function test.login_reply(t)
	local pkt = ServerPackets.loginReply(42)
	t:assert(#pkt > Binary.HEADER_SIZE)

	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.USER_ID)
	t:eq(bodyLen, 4)

	local userId = Binary.readI32(pkt, Binary.HEADER_SIZE + 1)
	t:eq(userId, 42)
end

function test.login_failure(t)
	local pkt = ServerPackets.loginReply(-1)
	local userId = Binary.readI32(pkt, Binary.HEADER_SIZE + 1)
	t:eq(userId, -1)
end

function test.pong(t)
	local pkt = ServerPackets.pong()
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.PONG)
	t:eq(bodyLen, 0)
end

function test.notification(t)
	local pkt = ServerPackets.notification("Hello!")
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.NOTIFICATION)

	local reader = PacketReader(pkt:sub(Binary.HEADER_SIZE + 1))
	t:eq(reader:readString(), "Hello!")
end

function test.user_stats(t)
	local pkt = ServerPackets.userStats(42, 0, "", "", 0, 0, 0, 10000, 0.95, 50, 50000, 100, 250)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.USER_STATS)
	t:assert(bodyLen > 0)
end

function test.user_presence(t)
	local pkt = ServerPackets.userPresence(42, "TestUser", 5, 840, 1, 0, -73.0, 42.0, 500)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.USER_PRESENCE)
	t:assert(bodyLen > 0)
end

function test.spectator_joined(t)
	local pkt = ServerPackets.spectatorJoined(123)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.SPECTATOR_JOINED)
	t:eq(bodyLen, 4)
end

function test.spectator_left(t)
	local pkt = ServerPackets.spectatorLeft(456)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.SPECTATOR_LEFT)
	t:eq(bodyLen, 4)
end

function test.user_logout(t)
	local pkt = ServerPackets.userLogout(789)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.USER_LOGOUT)
	t:eq(bodyLen, 5) -- i32 + u8
end

function test.bancho_privileges(t)
	local pkt = ServerPackets.banchoPrivileges(42)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.PRIVILEGES)
	t:eq(bodyLen, 4)
end

function test.friends_list(t)
	local pkt = ServerPackets.friendsList({1, 2, 3})
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.FRIENDS_LIST)
	t:assert(bodyLen > 0)
end

function test.channel_join(t)
	local pkt = ServerPackets.channelJoin("#general")
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.CHANNEL_JOIN_SUCCESS)

	local reader = PacketReader(pkt:sub(Binary.HEADER_SIZE + 1))
	t:eq(reader:readString(), "#general")
end

function test.channel_info(t)
	local pkt = ServerPackets.channelInfo("#test", "Topic", 5)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.CHANNEL_INFO)
	t:assert(bodyLen > 0)
end

function test.match_dispose(t)
	local pkt = ServerPackets.disposeMatch(42)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.DISPOSE_MATCH)
	t:eq(bodyLen, 4)
end

function test.match_join_fail(t)
	local pkt = ServerPackets.matchJoinFail()
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.MATCH_JOIN_FAIL)
	t:eq(bodyLen, 0)
end

function test.match_complete(t)
	local pkt = ServerPackets.matchComplete()
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.MATCH_COMPLETE)
	t:eq(bodyLen, 0)
end

function test.protocol_version(t)
	local pkt = ServerPackets.protocolVersion(1)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.PROTOCOL_VERSION)
	t:eq(bodyLen, 4)
end

function test.match_score_update(t)
	local sf = {
		time = 1000, id = 1, num300 = 10, num100 = 2, num50 = 1,
		num_geki = 0, num_katu = 0, num_miss = 0, total_score = 3300,
		max_combo = 50, current_combo = 13, perfect = false, current_hp = 100,
		tag_byte = 0, score_v2 = false,
	}
	local pkt = ServerPackets.matchScoreUpdate(sf)
	local id, bodyLen = Binary.readHeader(pkt, 1)
	t:eq(id, ServerPackets.MATCH_SCORE_UPDATE)
	t:assert(bodyLen > 0)
end

return test
