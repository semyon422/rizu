local MatchScoreUpdate = require("bancho.handler.MatchScoreUpdate")
local ServerPackets = require("bancho.protocol.ServerPackets")
local Binary = require("bancho.protocol.Binary")
local PacketReader = require("bancho.protocol.PacketReader")
local ComplexTypes = require("bancho.protocol.ComplexTypes")

local test = {}

function test.handle_sets_slot_id_in_score_frame(t)
	local handler = MatchScoreUpdate()
	local queued
	local target = {
		id = 2,
		token = "target-token",
		enqueue = function(self, data)
			queued = data
		end,
	}
	local player = {id = 10}
	local match = {
		in_progress = true,
		slots = {},
		getSlotId = function(self, _player)
			return 3
		end,
	}
	for i = 0, 15 do
		match.slots[i] = {}
	end
	match.slots[3].player = player
	match.slots[4].player = target
	player.match = match

	local server = {
		players = {
			_dict = nil,
			get = function() return nil end,
		},
	}

	handler:handle(server, player, {
		score_frame = {
			time = 1000,
			id = 0,
			num300 = 1,
			num100 = 2,
			num50 = 3,
			num_geki = 4,
			num_katu = 5,
			num_miss = 6,
			total_score = 12345,
			max_combo = 10,
			current_combo = 8,
			perfect = false,
			current_hp = 200,
			tag_byte = 0,
			score_v2 = false,
		},
	})

	t:ne(queued, nil)
	local id, bodyLen = Binary.readHeader(queued, 1)
	t:eq(id, ServerPackets.MATCH_SCORE_UPDATE)
	local frame = ComplexTypes.readScoreFrame(PacketReader(queued:sub(Binary.HEADER_SIZE + 1, Binary.HEADER_SIZE + bodyLen)))
	t:eq(frame.id, 3)
end

return test
