--- Tests for bancho protocol ComplexTypes.

local ComplexTypes = require("bancho.protocol.ComplexTypes")
local PacketReader = require("bancho.protocol.PacketReader")
local SlotStatus = require("bancho.constants.SlotStatus")

local test = {}

function test.scoreframe_roundtrip(t)
	local sf = {
		time = 12345,
		id = 42,
		num300 = 100,
		num100 = 10,
		num50 = 5,
		num_geki = 20,
		num_katu = 5,
		num_miss = 2,
		total_score = 123456,
		max_combo = 500,
		current_combo = 450,
		perfect = false,
		current_hp = 75,
		tag_byte = 0,
		score_v2 = false,
	}

	local data = ComplexTypes.writeScoreFrame(sf)
	local reader = PacketReader(data)

	local sf2 = ComplexTypes.readScoreFrame(reader)
	t:eq(sf2.time, sf.time)
	t:eq(sf2.id, sf.id)
	t:eq(sf2.num300, sf.num300)
	t:eq(sf2.num100, sf.num100)
	t:eq(sf2.num50, sf.num50)
	t:eq(sf2.num_geki, sf.num_geki)
	t:eq(sf2.num_katu, sf.num_katu)
	t:eq(sf2.num_miss, sf.num_miss)
	t:eq(sf2.total_score, sf.total_score)
	t:eq(sf2.max_combo, sf.max_combo)
	t:eq(sf2.current_combo, sf.current_combo)
	t:eq(sf2.perfect, sf.perfect)
	t:eq(sf2.current_hp, sf.current_hp)
	t:eq(sf2.score_v2, sf.score_v2)
end

function test.scoreframe_roundtrip_v2(t)
	local sf = {
		time = 0,
		id = 1,
		num300 = 50,
		num100 = 5,
		num50 = 0,
		num_geki = 10,
		num_katu = 2,
		num_miss = 0,
		total_score = 50000,
		max_combo = 100,
		current_combo = 100,
		perfect = true,
		current_hp = 100,
		tag_byte = 0,
		score_v2 = true,
		combo_portion = 123.456,
		bonus_portion = 789.012,
	}

	local data = ComplexTypes.writeScoreFrame(sf)
	local reader = PacketReader(data)

	local sf2 = ComplexTypes.readScoreFrame(reader)
	t:eq(sf2.score_v2, true)
	t:eq(sf2.combo_portion, 123.456)
	t:eq(sf2.bonus_portion, 789.012)
end

function test.message_roundtrip(t)
	local msg = {
		sender = "TestUser",
		text = "Hello world!",
		recipient = "#general",
		sender_id = 42,
	}

	local data = ComplexTypes.writeMessage(msg)
	local reader = PacketReader(data)

	local msg2 = ComplexTypes.readMessage(reader)
	t:eq(msg2.sender, msg.sender)
	t:eq(msg2.text, msg.text)
	t:eq(msg2.recipient, msg.recipient)
	t:eq(msg2.sender_id, msg.sender_id)
end

function test.channel_roundtrip(t)
	local ch = {
		name = "#test",
		topic = "Test channel",
		players = 5,
	}

	local data = ComplexTypes.writeChannel(ch)
	local reader = PacketReader(data)

	local ch2 = ComplexTypes.readChannel(reader)
	t:eq(ch2.name, ch.name)
	t:eq(ch2.topic, ch.topic)
	t:eq(ch2.players, ch.players)
end

function test.replayframe_roundtrip(t)
	local frame = {
		button_state = 15,
		taiko_byte = 0,
		x = 100.5,
		y = 200.25,
		time = 5000,
	}

	local w = require("bancho.protocol.PacketWriter")()
	w:writeU8(frame.button_state)
	w:writeU8(frame.taiko_byte)
	w:writeF32(frame.x)
	w:writeF32(frame.y)
	w:writeI32(frame.time)

	local reader = PacketReader(w.body)
	local frame2 = ComplexTypes.readReplayFrame(reader)
	t:eq(frame2.button_state, frame.button_state)
	t:eq(frame2.taiko_byte, frame.taiko_byte)
	t:eq(frame2.x, frame.x)
	t:eq(frame2.y, frame.y)
	t:eq(frame2.time, frame.time)
end

function test.match_read_basic(t)
	-- Build a minimal match packet
	local w = require("bancho.protocol.PacketWriter")()

	w:writeI16(1) -- id
	w:writeI8(0) -- in_progress
	w:writeI8(0) -- powerplay
	w:writeI32(0) -- mods
	w:writeString("Test Match") -- name
	w:writeRaw("\x00") -- no password
	w:writeString("Test Map") -- map_name
	w:writeI32(123) -- map_id
	w:writeString("abc123") -- map_md5

	-- 16 slot statuses (all OPEN = 0)
	for _ = 1, 16 do w:writeI8(0) end
	-- 16 slot teams (all NEUTRAL = 0)
	for _ = 1, 16 do w:writeI8(0) end
	-- no slot_ids (all slots empty)
	w:writeI32(1) -- host_id
	w:writeI8(0) -- mode
	w:writeI8(0) -- win_condition
	w:writeI8(0) -- team_type
	w:writeI8(0) -- freemods = false
	w:writeI32(0) -- seed

	local reader = PacketReader(w.body)
	local m = ComplexTypes.readMatch(reader)

	t:eq(m.id, 1)
	t:eq(m.in_progress, false)
	t:eq(m.name, "Test Match")
	t:eq(m.passwd, "")
	t:eq(m.map_name, "Test Map")
	t:eq(m.map_id, 123)
	t:eq(m.map_md5, "abc123")
	t:eq(#m.slot_statuses, 16)
	t:eq(#m.slot_teams, 16)
	t:eq(#m.slot_ids, 0)
	t:eq(m.host_id, 1)
	t:eq(m.mode, 0)
	t:eq(m.freemods, false)
end

return test
