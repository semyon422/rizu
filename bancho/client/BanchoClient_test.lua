--- Unit tests for bancho client.
---
--- Tests packet building, parsing, and client methods without requiring a running server.

local BanchoClient = require("bancho.client.BanchoClient")
local ClientConfig = require("bancho.client.ClientConfig")
local HttpTransport = require("bancho.client.HttpTransport")
local Binary = require("bancho.protocol.Binary")
local PacketReader = require("bancho.protocol.PacketReader")
local PacketWriter = require("bancho.protocol.PacketWriter")
local ServerPackets = require("bancho.protocol.ServerPackets")
local ClientPackets = require("bancho.protocol.ClientPackets")

local test = {}

--- ClientConfig builds correct URL.
function test.config_url(t)
	local config = ClientConfig {
		host = "example.com",
		port = 8091,
		scheme = "https",
	}
	t:eq(config:url(), "https://example.com:8091")
end

--- ClientConfig builds correct login body.
function test.config_login_body(t)
	local config = ClientConfig {
		username = "test",
		password_md5 = "abc123",
		osu_version = "b20240101r1stable",
		utc_offset = 3,
		pm_private = true,
	}
	local body = config:login_body()
	t:assert(body:find("test\nabc123\nb20240101r1stable|3|0|", 1, true))
	t:assert(body:find("|1\n")) -- pm_private=1 followed by newline
end

--- ClientConfig defaults.
function test.config_defaults(t)
	local config = ClientConfig {}
	t:eq(config.host, "localhost")
	t:eq(config.port, 8091)
	t:eq(config.scheme, "http")
	t:eq(config.timeout, 5)
	t:eq(config.max_retries, 3)
	t:eq(config.pm_private, false)
end

--- ClientConfig overrides.
function test.config_overrides(t)
	local config = ClientConfig {
		host = "custom.host",
		port = 9999,
		timeout = 10,
	}
	t:eq(config.host, "custom.host")
	t:eq(config.port, 9999)
	t:eq(config.timeout, 10)
	t:eq(config.scheme, "http") -- default preserved
end

--- HttpTransport parses packets correctly.
function test.transport_parse_packets(t)
	local transport = HttpTransport(ClientConfig {})

	-- Build a synthetic response: USER_ID packet + NOTIFICATION packet
	local user_id_pkt = Binary.writeHeader(ServerPackets.USER_ID, 4) .. Binary.writeI32(42)
	local notif_body = Binary.writeString("Hello")
	local notif_pkt = Binary.writeHeader(ServerPackets.NOTIFICATION, #notif_body) .. notif_body

	local combined = user_id_pkt .. notif_pkt
	local packets = transport:parse_packets(combined)

	t:eq(#packets, 2)
	t:eq(packets[1].id, ServerPackets.USER_ID)
	t:eq(Binary.readI32(packets[1].body, 1), 42)
	t:eq(packets[2].id, ServerPackets.NOTIFICATION)
end

--- Transport parse handles empty body.
function test.transport_parse_empty(t)
	local transport = HttpTransport(ClientConfig {})
	t:eq(#transport:parse_packets(""), 0)
	t:eq(#transport:parse_packets(nil), 0)
end

--- Transport parse handles multiple packets.
function test.transport_parse_multiple(t)
	local transport = HttpTransport(ClientConfig {})

	-- Build 3 packets: USER_ID, PONG, USER_STATS
	local pkt1 = Binary.writeHeader(ServerPackets.USER_ID, 4) .. Binary.writeI32(1)
	local pkt2 = Binary.writeHeader(ServerPackets.PONG, 0)
	local pkt3 = Binary.writeHeader(ServerPackets.USER_PRESENCE, 4) .. Binary.writeI32(999)

	local combined = pkt1 .. pkt2 .. pkt3
	local packets = transport:parse_packets(combined)

	t:eq(#packets, 3)
	t:eq(packets[1].id, ServerPackets.USER_ID)
	t:eq(packets[2].id, ServerPackets.PONG)
	t:eq(packets[3].id, ServerPackets.USER_PRESENCE)
end

--- Build packet creates correct binary.
function test.build_packet(t)
	local client = BanchoClient(ClientConfig {})
	local body = "test data"
	local packet = client:build_packet(1, body)

	-- Header: u16(1) + u8(0) + u32(9) = 7 bytes + body
	t:eq(#packet, 7 + #body)
	local id = Binary.readU16(packet, 1)
	t:eq(id, 1)
	t:eq(packet:sub(8), body)
end

--- Send without login returns error.
function test.send_not_logged_in(t)
	local client = BanchoClient(ClientConfig {})
	local packets, err = client:send("")
	t:eq(#packets, 0)
	t:assert(err:find("not logged in"))
end

--- Build chat message packet.
function test.build_chat_message(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("#general")
	w:writeString("Hello!")
	local packet = client:build_packet(ClientPackets.SEND_PUBLIC_MESSAGE, w.body)

	-- Verify packet structure
	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.SEND_PUBLIC_MESSAGE)
end

--- Build private message packet.
function test.build_private_message(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("TargetUser")
	w:writeString("Hey there!")
	local packet = client:build_packet(ClientPackets.SEND_PRIVATE_MESSAGE, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.SEND_PRIVATE_MESSAGE)
end

--- Build channel join packet.
function test.build_channel_join(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("#general")
	local packet = client:build_packet(ClientPackets.CHANNEL_JOIN, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.CHANNEL_JOIN)
end

--- Build channel part packet.
function test.build_channel_part(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("#general")
	local packet = client:build_packet(ClientPackets.CHANNEL_PART, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.CHANNEL_PART)
end

--- Build match create packet.
function test.build_match_create(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("My Match")
	w:writeString("secret")
	local packet = client:build_packet(ClientPackets.CREATE_MATCH, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.CREATE_MATCH)
end

--- Build match join packet.
function test.build_match_join(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeI32(5)
	w:writeString("secret")
	local packet = client:build_packet(ClientPackets.JOIN_MATCH, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.JOIN_MATCH)

	-- Verify match ID in body
	local body = packet:sub(8)
	local match_id = Binary.readI32(body, 1)
	t:eq(match_id, 5)
end

--- Build match part packet.
function test.build_match_part(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.PART_MATCH, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.PART_MATCH)
	t:eq(#packet, 7) -- header only, no body
end

--- Build match ready packet.
function test.build_match_ready(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_READY, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_READY)
end

--- Build match lock packet.
function test.build_match_lock(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeU8(1) -- lock
	local packet = client:build_packet(ClientPackets.MATCH_LOCK, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_LOCK)
end

--- Build match start packet.
function test.build_match_start(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_START, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_START)
end

--- Build match skip packet.
function test.build_match_skip(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_SKIP_REQUEST, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_SKIP_REQUEST)
end

--- Build match transfer host packet.
function test.build_match_transfer_host(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_TRANSFER_HOST, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_TRANSFER_HOST)
end

--- Build match change mods packet.
function test.build_match_change_mods(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeI32(1) -- mods bitmask (DT)
	local packet = client:build_packet(ClientPackets.MATCH_CHANGE_MODS, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_CHANGE_MODS)
end

--- Build match change team packet.
function test.build_match_change_team(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeU8(1) -- team (1=Team vs, team 1)
	local packet = client:build_packet(ClientPackets.MATCH_CHANGE_TEAM, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_CHANGE_TEAM)
end

--- Build match change password packet.
function test.build_match_change_password(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("newpass")
	local packet = client:build_packet(ClientPackets.MATCH_CHANGE_PASSWORD, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_CHANGE_PASSWORD)
end

--- Build match load complete packet.
function test.build_match_load_complete(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_LOAD_COMPLETE, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_LOAD_COMPLETE)
end

--- Build match no beatmap packet.
function test.build_match_no_beatmap(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_NO_BEATMAP, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_NO_BEATMAP)
end

--- Build match has beatmap packet.
function test.build_match_has_beatmap(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_HAS_BEATMAP, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_HAS_BEATMAP)
end

--- Build match failed packet.
function test.build_match_failed(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_FAILED, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_FAILED)
end

--- Build match complete packet.
function test.build_match_complete(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.MATCH_COMPLETE, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_COMPLETE)
end

--- Build match invite packet.
function test.build_match_invite(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("TargetUser")
	local packet = client:build_packet(ClientPackets.MATCH_INVITE, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.MATCH_INVITE)
end

--- Build join lobby packet.
function test.build_join_lobby(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.JOIN_LOBBY, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.JOIN_LOBBY)
end

--- Build part lobby packet.
function test.build_part_lobby(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.PART_LOBBY, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.PART_LOBBY)
end

--- Build ping packet.
function test.build_ping(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.PING, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.PING)
	t:eq(#packet, 7) -- header only
end

--- Build logout packet.
function test.build_logout(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.LOGOUT, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.LOGOUT)
end

--- Build status update packet.
function test.build_status_update(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeU8(0) -- mode
	w:writeString("Playing") -- info_text
	w:writeString("abc123") -- map_md5
	w:writeI32(1) -- mods (DT)
	w:writeU8(2) -- action (playing)
	w:writeI32(100) -- map_id
	local packet = client:build_packet(ClientPackets.REQUEST_STATUS_UPDATE, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.REQUEST_STATUS_UPDATE)
end

--- Build start spectating packet.
function test.build_start_spectating(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeI32(42)
	local packet = client:build_packet(ClientPackets.START_SPECTATING, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.START_SPECTATING)

	-- Verify user ID in body
	local body = packet:sub(8)
	local user_id = Binary.readI32(body, 1)
	t:eq(user_id, 42)
end

--- Build stop spectating packet.
function test.build_stop_spectating(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.STOP_SPECTATING, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.STOP_SPECTATING)
end

--- Build away message packet.
function test.build_away_message(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("BRB")
	local packet = client:build_packet(ClientPackets.SET_AWAY_MESSAGE, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.SET_AWAY_MESSAGE)
end

--- Build friend add packet.
function test.build_friend_add(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("NewFriend")
	local packet = client:build_packet(ClientPackets.FRIEND_ADD, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.FRIEND_ADD)
end

--- Build friend remove packet.
function test.build_friend_remove(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("OldFriend")
	local packet = client:build_packet(ClientPackets.FRIEND_REMOVE, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.FRIEND_REMOVE)
end

--- Build receive updates packet.
function test.build_receive_updates(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeU8(0) -- mode
	w:writeU8(1) -- 1=receive, 0=stop
	local packet = client:build_packet(ClientPackets.RECEIVE_UPDATES, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.RECEIVE_UPDATES)
end

--- Build user stats request packet.
function test.build_user_stats_request(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeI32(42)
	local packet = client:build_packet(ClientPackets.USER_STATS_REQUEST, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.USER_STATS_REQUEST)
end

--- Build user presence request packet.
function test.build_user_presence_request(t)
	local client = BanchoClient(ClientConfig {})
	local w = PacketWriter()
	w:writeString("TargetUser")
	local packet = client:build_packet(ClientPackets.USER_PRESENCE_REQUEST, w.body)

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.USER_PRESENCE_REQUEST)
end

--- Build user presence request all packet.
function test.build_user_presence_request_all(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.USER_PRESENCE_REQUEST_ALL, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.USER_PRESENCE_REQUEST_ALL)
end

--- Build toggle block non-friend DMs packet.
function test.build_toggle_block_dms(t)
	local client = BanchoClient(ClientConfig {})
	local packet = client:build_packet(ClientPackets.TOGGLE_BLOCK_NON_FRIEND_DMS, "")

	local id = Binary.readU16(packet, 1)
	t:eq(id, ClientPackets.TOGGLE_BLOCK_NON_FRIEND_DMS)
end

--- Parse login response with user_id.
function test.parse_login_response(t)
	local transport = HttpTransport(ClientConfig {})

	-- Simulate successful login response
	local protocol_ver = Binary.writeHeader(ServerPackets.PROTOCOL_VERSION, 4) .. Binary.writeI32(19)
	local user_id = Binary.writeHeader(ServerPackets.USER_ID, 4) .. Binary.writeI32(42)
	local privs = Binary.writeHeader(ServerPackets.PRIVILEGES, 4) .. Binary.writeI32(1)
	local notif_body = Binary.writeString("Welcome!")
	local notif = Binary.writeHeader(ServerPackets.NOTIFICATION, #notif_body) .. notif_body

	local combined = protocol_ver .. user_id .. privs .. notif
	local packets = transport:parse_packets(combined)

	t:eq(#packets, 4)
	t:eq(packets[1].id, ServerPackets.PROTOCOL_VERSION)
	t:eq(Binary.readI32(packets[1].body, 1), 19)
	t:eq(packets[2].id, ServerPackets.USER_ID)
	t:eq(Binary.readI32(packets[2].body, 1), 42)
	t:eq(packets[3].id, ServerPackets.PRIVILEGES)
	t:eq(Binary.readI32(packets[3].body, 1), 1)
	t:eq(packets[4].id, ServerPackets.NOTIFICATION)
end

--- Parse notification message.
function test.parse_notification(t)
	local transport = HttpTransport(ClientConfig {})

	local notif_body = Binary.writeString("Server restarted")
	local pkt = Binary.writeHeader(ServerPackets.NOTIFICATION, #notif_body) .. notif_body

	local packets = transport:parse_packets(pkt)
	t:eq(#packets, 1)

	local reader = PacketReader(packets[1].body)
	local msg = reader:readString()
	t:eq(msg, "Server restarted")
end

--- Parse restart server packet.
function test.parse_restart_server(t)
	local transport = HttpTransport(ClientConfig {})

	local pkt = Binary.writeHeader(ServerPackets.RESTART_SERVER, 4) .. Binary.writeI32(5000)
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.RESTART_SERVER)
	t:eq(Binary.readI32(packets[1].body, 1), 5000)
end

--- Parse channel join success.
function test.parse_channel_join_success(t)
	local transport = HttpTransport(ClientConfig {})

	local chan_body = Binary.writeString("#general")
	local pkt = Binary.writeHeader(ServerPackets.CHANNEL_JOIN_SUCCESS, #chan_body) .. chan_body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.CHANNEL_JOIN_SUCCESS)

	local reader = PacketReader(packets[1].body)
	local name = reader:readString()
	t:eq(name, "#general")
end

--- Parse match join success.
function test.parse_match_join_success(t)
	local transport = HttpTransport(ClientConfig {})

	-- NEW_MATCH packet (id=27) with minimal match data
	-- Match data: id(i32), name(string), passwd(string), host_id(i32), map_id(i32),
	--   map_md5(string), map_name(string), mode(u8), mods(i32), win_condition(u8),
	--   team_type(u8), freemods(u8), slots[16]{player_id(i32), status(u8), team(u8), mods(i32)}
	local w = PacketWriter()
	w:writeI32(1) -- match id
	w:writeString("Test Match") -- name
	w:writeString("") -- password
	w:writeI32(1) -- host_id
	w:writeI32(100) -- map_id
	w:writeString("abc123") -- map_md5
	w:writeString("Test Map") -- map_name
	w:writeU8(0) -- mode
	w:writeI32(0) -- mods
	w:writeU8(0) -- win_condition
	w:writeU8(0) -- team_type
	w:writeU8(0) -- freemods
	for i = 0, 15 do
		w:writeI32(0) -- player_id
		w:writeU8(0) -- status
		w:writeU8(0) -- team
		w:writeI32(0) -- mods
	end

	local pkt = Binary.writeHeader(ServerPackets.MATCH_JOIN_SUCCESS, #w.body) .. w.body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.MATCH_JOIN_SUCCESS)
end

--- Parse friends list.
function test.parse_friends_list(t)
	local transport = HttpTransport(ClientConfig {})

	local friends_body = Binary.writeI32List({1, 2, 3})
	local pkt = Binary.writeHeader(ServerPackets.FRIENDS_LIST, #friends_body) .. friends_body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.FRIENDS_LIST)

	local reader = PacketReader(packets[1].body)
	local friends = reader:readI32List()
	t:eq(#friends, 3)
	t:eq(friends[1], 1)
	t:eq(friends[2], 2)
	t:eq(friends[3], 3)
end

--- Parse user presence.
function test.parse_user_presence(t)
	local transport = HttpTransport(ClientConfig {})

	local w = PacketWriter()
	w:writeI32(42) -- user_id
	w:writeString("TestUser") -- name
	w:writeU8(27) -- utc_offset + 24
	w:writeU8(0) -- country_code
	w:writeU8(1) -- bancho_privileges | mode
	w:writeF32(0) -- longitude
	w:writeF32(0) -- latitude
	w:writeI32(100) -- global_rank

	local pkt = Binary.writeHeader(ServerPackets.USER_PRESENCE, #w.body) .. w.body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.USER_PRESENCE)

	local reader = PacketReader(packets[1].body)
	t:eq(reader:readI32(), 42) -- user_id
	t:eq(reader:readString(), "TestUser") -- name
end

--- Parse user stats.
function test.parse_user_stats(t)
	local transport = HttpTransport(ClientConfig {})

	local w = PacketWriter()
	w:writeI32(42) -- user_id
	w:writeU8(2) -- action
	w:writeString("Playing") -- info_text
	w:writeString("abc123") -- map_md5
	w:writeI32(1) -- mods
	w:writeU8(0) -- mode
	w:writeI32(100) -- map_id
	w:writeI64(50000) -- ranked_score
	w:writeF32(95.5) -- accuracy
	w:writeI32(100) -- plays
	w:writeI64(1000000) -- total_score
	w:writeI32(50) -- global_rank
	w:writeU16(100) -- pp

	local pkt = Binary.writeHeader(ServerPackets.USER_STATS, #w.body) .. w.body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.USER_STATS)

	local reader = PacketReader(packets[1].body)
	t:eq(reader:readI32(), 42) -- user_id
	t:eq(reader:readU8(), 2) -- action
	t:eq(reader:readString(), "Playing") -- info_text
end

--- Parse channel info.
function test.parse_channel_info(t)
	local transport = HttpTransport(ClientConfig {})

	-- Channel info: name(string), topic(string), player_count(u16)
	local w = PacketWriter()
	w:writeString("#general")
	w:writeString("General discussion")
	w:writeU16(5)

	local pkt = Binary.writeHeader(ServerPackets.CHANNEL_INFO, #w.body) .. w.body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.CHANNEL_INFO)

	local reader = PacketReader(packets[1].body)
	t:eq(reader:readString(), "#general")
	t:eq(reader:readString(), "General discussion")
	t:eq(reader:readU16(), 5)
end

--- Parse spectator joined.
function test.parse_spectator_joined(t)
	local transport = HttpTransport(ClientConfig {})

	local pkt = Binary.writeHeader(ServerPackets.SPECTATOR_JOINED, 4) .. Binary.writeI32(99)
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.SPECTATOR_JOINED)
	t:eq(Binary.readI32(packets[1].body, 1), 99)
end

--- Parse match skip.
function test.parse_match_skip(t)
	local transport = HttpTransport(ClientConfig {})

	local pkt = Binary.writeHeader(ServerPackets.MATCH_SKIP, 0)
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.MATCH_SKIP)
	t:eq(packets[1].bodyLen, 0)
end

--- Parse user logout.
function test.parse_user_logout(t)
	local transport = HttpTransport(ClientConfig {})

	local w = PacketWriter()
	w:writeI32(42) -- user_id
	w:writeU8(0) -- reason

	local pkt = Binary.writeHeader(ServerPackets.USER_LOGOUT, #w.body) .. w.body
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.USER_LOGOUT)
end

--- Parse dispose match.
function test.parse_dispose_match(t)
	local transport = HttpTransport(ClientConfig {})

	local pkt = Binary.writeHeader(ServerPackets.DISPOSE_MATCH, 4) .. Binary.writeI32(5)
	local packets = transport:parse_packets(pkt)

	t:eq(#packets, 1)
	t:eq(packets[1].id, ServerPackets.DISPOSE_MATCH)
	t:eq(Binary.readI32(packets[1].body, 1), 5)
end

--- Client state management.
function test.client_state(t)
	local client = BanchoClient(ClientConfig {})

	-- Initially not logged in
	t:eq(client.logged_in, false)
	t:eq(client.user_id, nil)

	-- Simulate successful login
	client.logged_in = true
	client.user_id = 42
	t:eq(client.logged_in, true)
	t:eq(client.user_id, 42)

	-- Logout
	client.logged_in = false
	client.user_id = nil
	t:eq(client.logged_in, false)
	t:eq(client.user_id, nil)
end

return test
