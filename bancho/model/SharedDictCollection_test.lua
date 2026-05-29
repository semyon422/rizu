--- Integration tests for shared dict-backed collections.
---
--- Verifies that PlayerCollection, MatchCollection, and ChannelCollection
--- work correctly with FakeSharedDict (stand-in for NginxSharedDict).
--- Tests multi-instance sharing, packet queues, and serialization round-trips.

local FakeSharedDict = require("web.nginx.FakeSharedDict")
local PlayerCollection = require("bancho.model.PlayerCollection")
local MatchCollection = require("bancho.model.MatchCollection")
local ChannelCollection = require("bancho.model.ChannelCollection")
local Player = require("bancho.model.Player")
local Match = require("bancho.model.Match")
local Channel = require("bancho.model.Channel")
local MatchConstants = require("bancho.constants.MatchConstants")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")

local test = {}

--- Two collections sharing the same dict see each other's players.
function test.multi_instance_players(t)
	local dict = FakeSharedDict()
	local col1 = PlayerCollection(dict)
	local col2 = PlayerCollection(dict)

	local p = Player(1, "TestUser", 1)
	col1:add(p)

	-- col2 can see player added by col1
	local found = col2:get(p.token)
	t:ne(found, nil)
	t:eq(found.id, 1)
	t:eq(found.name, "TestUser")
	t:eq(found.token, p.token)

	-- Both collections report the same count
	t:eq(col1:len(), 1)
	t:eq(col2:len(), 1)

	-- Remove via col2, col1 sees it removed
	col2:remove(found)
	t:eq(col1:get(p.token), nil)
	t:eq(col1:len(), 0)
end

--- Player lookup by ID and name works across instances.
function test.player_lookup_by_id_and_name(t)
	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	local p = Player(42, "Alpha Beta", 0)
	col:add(p)

	t:ne(col:get(nil, 42), nil)
	t:eq(col:get(nil, 42).id, 42)

	t:ne(col:get(nil, nil, "Alpha Beta"), nil)
	t:eq(col:get(nil, nil, "Alpha Beta").id, 42)
end

--- Player data round-trip preserves all fields.
function test.player_serialization_roundtrip(t)
	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	local p = Player(7, "RoundTrip", 3)
	p.restricted = true
	p.silenced = true
	p.silence_end = 1000
	p.utc_offset = 5
	p.pm_private = true
	p.stealth = true
	p.in_lobby = true
	p.away_msg = "brb"
	p.pres_filter = 2

	col:add(p)

	local found = col:get(p.token)
	t:eq(found.id, 7)
	t:eq(found.name, "RoundTrip")
	t:eq(found.priv, 3)
	t:eq(found.restricted, true)
	t:eq(found.silenced, true)
	t:eq(found.silence_end, 1000)
	t:eq(found.utc_offset, 5)
	t:eq(found.pm_private, true)
	t:eq(found.stealth, true)
	t:eq(found.in_lobby, true)
	t:eq(found.away_msg, "brb")
	t:eq(found.pres_filter, 2)
end

--- Packet queue via dict list ops.
function test.packet_queue_drain(t)
	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	local p = Player(1, "QueueUser", 0)
	col:add(p)

	-- Enqueue packets via collection
	col:enqueue("pkt1", {})
	col:enqueue("pkt2", {})

	-- Drain via drain_packets
	local data = col:drain_packets(p.token)
	t:eq(data, "pkt1pkt2")

	-- Queue is now empty
	local empty = col:drain_packets(p.token)
	t:eq(empty, nil)
end

--- Enqueue with immunity skips specified players.
function test.enqueue_immunity(t)
	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	local p1 = Player(1, "User1", 0)
	local p2 = Player(2, "User2", 0)
	col:add(p1)
	col:add(p2)

	col:enqueue("hello", {p1})

	-- p1 should have no packets
	t:eq(col:drain_packets(p1.token), nil)

	-- p2 should have the packet
	t:eq(col:drain_packets(p2.token), "hello")
end

--- Match CRUD with shared dict.
function test.match_crud(t)
	local dict = FakeSharedDict()
	local col = MatchCollection(dict)

	local m = Match(3, "Test Match", "pass", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	m.map_id = 123
	m.map_md5 = "abc123"
	m.map_name = "Test Map"
	m.in_progress = true

	col:add(m)

	local found = col:get(3)
	t:ne(found, nil)
	t:eq(found.id, 3)
	t:eq(found.name, "Test Match")
	t:eq(found.map_id, 123)
	t:eq(found.map_md5, "abc123")
	t:eq(found.map_name, "Test Map")
	t:eq(found.in_progress, true)

	col:remove(found)
	t:eq(col:get(3), nil)
end

--- Multi-instance match sharing.
function test.multi_instance_matches(t)
	local dict = FakeSharedDict()
	local col1 = MatchCollection(dict)
	local col2 = MatchCollection(dict)

	local m = Match(5, "Shared Match", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	col1:add(m)

	t:ne(col2:get(5), nil)
	t:eq(col2:get(5).id, 5)

	col2:remove(col2:get(5))
	t:eq(col1:get(5), nil)
end

--- Match getFree works with dict.
function test.match_get_free(t)
	local dict = FakeSharedDict()
	local col = MatchCollection(dict, 10)

	t:eq(col:getFree(), 1)

	local m1 = Match(1, "M1", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	local m3 = Match(3, "M3", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	col:add(m1)
	col:add(m3)

	t:eq(col:getFree(), 2) -- slot 2 is free
end

--- Channel CRUD with shared dict.
function test.channel_crud(t)
	local dict = FakeSharedDict()
	local col = ChannelCollection(dict)

	local c = Channel("#test", "Test channel", 0, 0, true, false)
	col:add(c)

	local found = col:get("#test")
	t:ne(found, nil)
	t:eq(found.real_name, "#test")
	t:eq(found.topic, "Test channel")
	t:eq(found.auto_join, true)

	col:remove(found)
	t:eq(col:get("#test"), nil)
end

--- Multi-instance channel sharing.
function test.multi_instance_channels(t)
	local dict = FakeSharedDict()
	local col1 = ChannelCollection(dict)
	local col2 = ChannelCollection(dict)

	local c = Channel("#shared", "Shared", 0, 0, false, false)
	col1:add(c)

	t:ne(col2:get("#shared"), nil)
	t:eq(col2:len(), 1)

	col2:remove(col2:get("#shared"))
	t:eq(col1:len(), 0)
end

--- PlayerCollection:all() returns all players from dict.
function test.player_all(t)
	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	col:add(Player(1, "A", 0))
	col:add(Player(2, "B", 0))
	col:add(Player(3, "C", 0))

	local all = col:all()
	t:eq(#all, 3)
end

--- PlayerCollection:ids() returns correct set.
function test.player_ids(t)
	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	col:add(Player(10, "X", 0))
	col:add(Player(20, "Y", 0))

	local ids = col:ids()
	t:eq(ids[10], true)
	t:eq(ids[20], true)
	t:eq(ids[30], nil)
end

--- PlayerCollection:staff() filters correctly.
function test.player_staff(t)
	local Privileges = require("bancho.constants.Privileges")

	local dict = FakeSharedDict()
	local col = PlayerCollection(dict)

	col:add(Player(1, "Normal", 0))
	col:add(Player(2, "Mod", Privileges.MODERATOR))
	col:add(Player(3, "Admin", Privileges.ADMINISTRATOR))

	local staff = col:staff()
	t:eq(#staff, 2)
end

--- In-memory collections still work (no dict).
function test.in_memory_fallback(t)
	local col = PlayerCollection()
	local p = Player(1, "MemUser", 0)

	col:add(p)
	t:eq(col:len(), 1)
	t:eq(col:get(p.token), p)
	t:eq(col:get(nil, 1), p)

	col:enqueue("data")
	t:eq(p:dequeue(), "data")

	col:remove(p)
	t:eq(col:len(), 0)
end

--- MatchCollection in-memory fallback.
function test.match_in_memory_fallback(t)
	local col = MatchCollection()
	local m = Match(2, "MemMatch", "", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)

	col:add(m)
	t:eq(col:get(2), m)
	t:eq(col:getFree(), 1)

	col:remove(m)
	t:eq(col:get(2), nil)
end

--- ChannelCollection in-memory fallback.
function test.channel_in_memory_fallback(t)
	local col = ChannelCollection()
	local c = Channel("#mem", "Memory", 0, 0, false, false)

	col:add(c)
	t:eq(col:get("#mem"), c)
	t:eq(col:len(), 1)

	col:remove(c)
	t:eq(col:get("#mem"), nil)
	t:eq(col:len(), 0)
end

--- Player:toData() produces clean serializable data.
function test.player_to_data(t)
	local p = Player(99, "DataUser", 1)
	p.restricted = true
	p.away_msg = "testing"

	local data = p:toData()
	t:eq(data.id, 99)
	t:eq(data.name, "DataUser")
	t:eq(data.token, p.token)
	t:eq(data.restricted, true)
	t:eq(data.away_msg, "testing")
	t:eq(data.spectating_id, nil)
	t:eq(data.match_id, nil)
	t:eq(type(data.spectators), "table")
	t:eq(type(data.status), "table")
	t:eq(type(data.stats), "table")
end

--- Match:toData() produces clean serializable data.
function test.match_to_data(t)
	local m = Match(7, "DataMatch", "pw", 1, GameMode.VANILLA_OSU, Mods.NOMOD,
		MatchConstants.MatchWinConditions.SCORE, MatchConstants.MatchTeamTypes.HEAD_TO_HEAD, false)
	m.map_id = 456
	m.in_progress = true

	local data = m:toData()
	t:eq(data.id, 7)
	t:eq(data.name, "DataMatch")
	t:eq(data.passwd, "pw")
	t:eq(data.map_id, 456)
	t:eq(data.in_progress, true)
	t:eq(type(data.slots), "table")
	t:eq(data.slots[0].player_id, nil)
end

--- Channel:toData() produces clean serializable data.
function test.channel_to_data(t)
	local c = Channel("#data", "Data channel", 1, 0, true, true)
	local data = c:toData()
	t:eq(data.name, "#data")
	t:eq(data.real_name, "#data")
	t:eq(data.topic, "Data channel")
	t:eq(data.read_priv, 1)
	t:eq(data.write_priv, 0)
	t:eq(data.auto_join, true)
	t:eq(data.instance, true)
	t:eq(type(data.player_ids), "table")
end

return test
