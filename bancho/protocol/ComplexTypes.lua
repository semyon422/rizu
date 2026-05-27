--- Complex type readers/writers for Bancho protocol packets.
---
--- Handles multi-field types: match, scoreframe, replayframe, message, channel.

local bit = require("bit")

local PacketReader = require("bancho.protocol.PacketReader")
local PacketWriter = require("bancho.protocol.PacketWriter")
local Binary = require("bancho.protocol.Binary")

local M = {}

--- Score frame data structure.
---@class bancho.protocol.ScoreFrame
---@field time integer
---@field id integer
---@field num300 integer
---@field num100 integer
---@field num50 integer
---@field num_geki integer
---@field num_katu integer
---@field num_miss integer
---@field total_score integer
---@field max_combo integer
---@field current_combo integer
---@field perfect boolean
---@field current_hp integer
---@field tag_byte integer
---@field score_v2 boolean
---@field combo_portion? number
---@field bonus_portion? number

--- Replay frame data structure.
---@class bancho.protocol.ReplayFrame
---@field button_state integer
---@field taiko_byte integer
---@field x number
---@field y number
---@field time integer

--- Replay frame bundle.
---@class bancho.protocol.ReplayFrameBundle
---@field frames bancho.protocol.ReplayFrame[]
---@field score_frame bancho.protocol.ScoreFrame
---@field action integer
---@field extra integer
---@field sequence integer

--- Multiplayer match data.
---@class bancho.protocol.MultiplayerMatch
---@field id integer
---@field in_progress boolean
---@field powerplay integer
---@field mods integer
---@field name string
---@field passwd string
---@field map_name string
---@field map_id integer
---@field map_md5 string
---@field slot_statuses integer[]
---@field slot_teams integer[]
---@field slot_ids integer[]
---@field slot_mods integer[]?
---@field host_id integer
---@field mode integer
---@field win_condition integer
---@field team_type integer
---@field freemods boolean
---@field seed integer

--- Chat message data.
---@class bancho.protocol.Message
---@field sender string
---@field text string
---@field recipient string
---@field sender_id integer

--- Channel data.
---@class bancho.protocol.Channel
---@field name string
---@field topic string
---@field players integer

-- ---------------------------------------------------------------
-- Readers
-- ---------------------------------------------------------------

--- Read a match from packet body.
---@param reader bancho.protocol.PacketReader
---@return bancho.protocol.MultiplayerMatch
function M.readMatch(reader)
	local m = {}
	m.id = reader:readI16()
	m.in_progress = reader:readI8() == 1
	m.powerplay = reader:readI8()
	m.mods = reader:readI32()
	m.name = reader:readString()
	m.passwd = reader:readString()
	m.map_name = reader:readString()
	m.map_id = reader:readI32()
	m.map_md5 = reader:readString()

	m.slot_statuses = {}
	m.slot_teams = {}
	for _ = 1, 16 do
		table.insert(m.slot_statuses, reader:readI8())
	end
	for _ = 1, 16 do
		table.insert(m.slot_teams, reader:readI8())
	end

	m.slot_ids = {}
	for _, status in ipairs(m.slot_statuses) do
		if bit.band(status, 124) ~= 0 then
			table.insert(m.slot_ids, reader:readI32())
		end
	end

	m.host_id = reader:readI32()
	m.mode = reader:readI8()
	m.win_condition = reader:readI8()
	m.team_type = reader:readI8()
	m.freemods = reader:readI8() == 1

	if m.freemods then
		m.slot_mods = {}
		for _ = 1, 16 do
			table.insert(m.slot_mods, reader:readI32())
		end
	else
		m.slot_mods = nil
	end

	m.seed = reader:readI32()

	return m
end

--- Read a score frame from packet body.
---@param reader bancho.protocol.PacketReader
---@return bancho.protocol.ScoreFrame
function M.readScoreFrame(reader)
	local sf = {}
	sf.time = reader:readI32()
	sf.id = reader:readU8()
	sf.num300 = reader:readU16()
	sf.num100 = reader:readU16()
	sf.num50 = reader:readU16()
	sf.num_geki = reader:readU16()
	sf.num_katu = reader:readU16()
	sf.num_miss = reader:readU16()
	sf.total_score = reader:readI32()
	sf.max_combo = reader:readU16()
	sf.current_combo = reader:readU16()
	sf.perfect = reader:readU8() == 1
	sf.current_hp = reader:readU8()
	sf.tag_byte = reader:readU8()
	sf.score_v2 = reader:readU8() == 1

	if sf.score_v2 then
		sf.combo_portion = reader:readF64()
		sf.bonus_portion = reader:readF64()
	end

	return sf
end

--- Read a replay frame from packet body.
---@param reader bancho.protocol.PacketReader
---@return bancho.protocol.ReplayFrame
function M.readReplayFrame(reader)
	return {
		button_state = reader:readU8(),
		taiko_byte = reader:readU8(),
		x = reader:readF32(),
		y = reader:readF32(),
		time = reader:readI32(),
	}
end

--- Read a replay frame bundle from packet body.
---@param reader bancho.protocol.PacketReader
---@return bancho.protocol.ReplayFrameBundle
function M.readReplayFrameBundle(reader)
	local extra = reader:readI32()
	local framecount = reader:readU16()

	local frames = {}
	for _ = 1, framecount do
		table.insert(frames, M.readReplayFrame(reader))
	end

	local action = reader:readU8()
	local score_frame = M.readScoreFrame(reader)
	local sequence = reader:readU16()

	return {
		frames = frames,
		score_frame = score_frame,
		action = action,
		extra = extra,
		sequence = sequence,
	}
end

--- Read a chat message from packet body.
---@param reader bancho.protocol.PacketReader
---@return bancho.protocol.Message
function M.readMessage(reader)
	return {
		sender = reader:readString(),
		text = reader:readString(),
		recipient = reader:readString(),
		sender_id = reader:readI32(),
	}
end

--- Read a channel from packet body.
---@param reader bancho.protocol.PacketReader
---@return bancho.protocol.Channel
function M.readChannel(reader)
	return {
		name = reader:readString(),
		topic = reader:readString(),
		players = reader:readI32(),
	}
end

-- ---------------------------------------------------------------
-- Writers
-- ---------------------------------------------------------------

--- Write a match to packet body.
---@param m bancho.protocol.MultiplayerMatch
---@param send_pw? boolean
---@return string
function M.writeMatch(m, send_pw)
	local w = PacketWriter()

	w:writeI16(m.id)
	w:writeI8(m.in_progress and 1 or 0)
	w:writeI8(m.powerplay or 0)
	w:writeI32(m.mods)
	w:writeString(m.name)

	if m.passwd and #m.passwd > 0 then
		if send_pw ~= false then
			w:writeString(m.passwd)
		else
			w:writeRaw("\x0b\x00")
		end
	else
		w:writeRaw("\x00")
	end

	w:writeString(m.map_name)
	w:writeI32(m.map_id)
	w:writeString(m.map_md5)

	for _, s in ipairs(m.slot_statuses) do
		w:writeI8(s)
	end
	for _, t in ipairs(m.slot_teams) do
		w:writeI8(t)
	end

	for i = 1, #m.slot_statuses do
		if bit.band(m.slot_statuses[i], 0b01111100) ~= 0 then
			w:writeI32(m.slot_ids[i] or 0)
		end
	end

	w:writeI32(m.host_id)
	w:writeI8(m.mode)
	w:writeI8(m.win_condition)
	w:writeI8(m.team_type)
	w:writeI8(m.freemods and 1 or 0)

	if m.freemods and m.slot_mods then
		for _, mods in ipairs(m.slot_mods) do
			w:writeI32(mods)
		end
	end

	w:writeI32(m.seed or 0)

	return w.body
end

--- Write a score frame to packet body.
---@param sf bancho.protocol.ScoreFrame
---@return string
function M.writeScoreFrame(sf)
	local w = PacketWriter()

	w:writeI32(sf.time)
	w:writeU8(sf.id)
	w:writeU16(sf.num300)
	w:writeU16(sf.num100)
	w:writeU16(sf.num50)
	w:writeU16(sf.num_geki)
	w:writeU16(sf.num_katu)
	w:writeU16(sf.num_miss)
	w:writeI32(sf.total_score)
	w:writeU16(sf.max_combo)
	w:writeU16(sf.current_combo)
	w:writeU8(sf.perfect and 1 or 0)
	w:writeU8(sf.current_hp)
	w:writeU8(sf.tag_byte)
	w:writeU8(sf.score_v2 and 1 or 0)

	if sf.score_v2 then
		w:writeF64(sf.combo_portion or 0)
		w:writeF64(sf.bonus_portion or 0)
	end

	return w.body
end

--- Write a replay frame bundle to packet body.
---@param bundle bancho.protocol.ReplayFrameBundle
---@return string
function M.writeReplayFrameBundle(bundle)
	local w = PacketWriter()

	w:writeI32(bundle.extra or 0)
	w:writeU16(#bundle.frames)

	for _, frame in ipairs(bundle.frames) do
		w:writeU8(frame.button_state)
		w:writeU8(frame.taiko_byte)
		w:writeF32(frame.x)
		w:writeF32(frame.y)
		w:writeI32(frame.time)
	end

	w:writeU8(bundle.action)
	w:writeRaw(M.writeScoreFrame(bundle.score_frame))
	w:writeU16(bundle.sequence)

	return w.body
end

--- Write a chat message to packet body.
---@param msg bancho.protocol.Message
---@return string
function M.writeMessage(msg)
	local w = PacketWriter()

	w:writeString(msg.sender)
	w:writeString(msg.text)
	w:writeString(msg.recipient)
	w:writeI32(msg.sender_id)

	return w.body
end

--- Write a channel to packet body.
---@param ch bancho.protocol.Channel
---@return string
function M.writeChannel(ch)
	local w = PacketWriter()

	w:writeString(ch.name)
	w:writeString(ch.topic)
	w:writeI32(ch.players)

	return w.body
end

return M
