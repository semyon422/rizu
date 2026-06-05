local ChangeAction = require("bancho.handler.ChangeAction")
local Binary = require("bancho.protocol.Binary")
local PacketReader = require("bancho.protocol.PacketReader")
local ServerPackets = require("bancho.protocol.ServerPackets")
local GameMode = require("bancho.constants.GameMode")
local Action = require("bancho.constants.Action")
local Mods = require("bancho.constants.Mods")

local test = {}

function test.parse(t)
	local handler = ChangeAction()

	-- Build packet body: action(u8), info_text(string), map_md5(string), mods(u32), mode(u8), map_id(i32)
	local body = Binary.writeU8(2)                          -- action: PLAYING
		.. Binary.writeString("Testing")                    -- info_text
		.. Binary.writeString("00000000000000000000000000000000") -- map_md5
		.. Binary.writeU32(0)                               -- mods
		.. Binary.writeU8(0)                                -- mode
		.. Binary.writeI32(12345)                           -- map_id

	local reader = PacketReader(body)
	local data = handler:parse(reader, #body)

	t:eq(data.action, 2)
	t:eq(data.info_text, "Testing")
	t:eq(data.map_md5, "00000000000000000000000000000000")
	t:eq(data.mods, 0)
	t:eq(data.mode, 0)
	t:eq(data.map_id, 12345)
end

function test.handle_calls_fromValue(t)
	local handler = ChangeAction()

	local data = {
		action = 2,
		info_text = "Testing",
		map_md5 = "00000000000000000000000000000000",
		mods = 0,
		mode = 0,
		map_id = 12345,
	}

	local player = {
		id = 1,
		status = { mode = GameMode.fromValue(0) },
		stats = {
			[0] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
		},
	}

	local enqueue_calls = {}
	local server = {
		players = {
			enqueue = function(_, packet, immune)
				table.insert(enqueue_calls, {packet = packet, immune = immune})
			end,
		},
	}

	-- Should not error — Action.fromValue must exist
	handler:handle(server, player, data)
	t:eq(player.status.action, 2)
	t:eq(player.status.mode, GameMode.fromValue(0))
	t:eq(#enqueue_calls, 1)
	t:eq(enqueue_calls[1].immune, nil)
end

function test.handle_relax_mode(t)
	local handler = ChangeAction()

	local data = {
		action = 2,
		info_text = "",
		map_md5 = "",
		mods = Mods.RELAX,
		mode = 0, -- osu!
		map_id = 0,
	}

	local player = {
		id = 1,
		status = { mode = GameMode.fromValue(0) },
		stats = {
			[0] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
			[4] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
		},
	}

	local server = {
		players = {
			enqueue = function() end,
		},
	}

	handler:handle(server, player, data)
	-- Relax + osu! (mode 0) = mode 4 (RELAX_OSU), RELAX bit kept
	t:eq(player.status.mode.value, 4)
	t:eq(player.status.mods, Mods.RELAX)
end

function test.handle_relax_mania(t)
	local handler = ChangeAction()

	local data = {
		action = 2,
		info_text = "",
		map_md5 = "",
		mods = Mods.RELAX,
		mode = 3, -- mania
		map_id = 0,
	}

	local player = {
		id = 1,
		status = { mode = GameMode.fromValue(3) },
		stats = {
			[0] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
			[3] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
		},
	}

	local server = {
		players = {
			enqueue = function() end,
		},
	}

	handler:handle(server, player, data)
	-- Relax + mania (mode 3) = mode stays 3, RELAX bit stripped
	t:eq(player.status.mode.value, 3)
	t:eq(bit.band(player.status.mods, Mods.RELAX), 0)
end

function test.handle_autopilot_mode(t)
	local handler = ChangeAction()

	local data = {
		action = 2,
		info_text = "",
		map_md5 = "",
		mods = Mods.AUTOPILOT,
		mode = 0, -- osu!
		map_id = 0,
	}

	local player = {
		id = 1,
		status = { mode = GameMode.fromValue(0) },
		stats = {
			[0] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
			[8] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
		},
	}

	local server = {
		players = {
			enqueue = function() end,
		},
	}

	handler:handle(server, player, data)
	-- Autopilot + osu! (mode 0) = mode 8 (AUTOPILOT_OSU), AUTOPILOT bit kept
	t:eq(player.status.mode.value, 8)
	t:eq(player.status.mods, Mods.AUTOPILOT)
end

function test.handle_autopilot_taiko(t)
	local handler = ChangeAction()

	local data = {
		action = 2,
		info_text = "",
		map_md5 = "",
		mods = Mods.AUTOPILOT,
		mode = 1, -- taiko
		map_id = 0,
	}

	local player = {
		id = 1,
		status = { mode = GameMode.fromValue(1) },
		stats = {
			[0] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
			[1] = { rscore = 0, acc = 100, plays = 0, tscore = 0, rank = 0, pp = 0 },
		},
	}

	local server = {
		players = {
			enqueue = function() end,
		},
	}

	handler:handle(server, player, data)
	-- Autopilot + taiko (mode 1) = mode stays 1, AUTOPILOT bit stripped
	t:eq(player.status.mode.value, 1)
	t:eq(bit.band(player.status.mods, Mods.AUTOPILOT), 0)
end

return test
