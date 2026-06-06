local MatchTransferHost = require("bancho.handler.MatchTransferHost")

local test = {}

function test.handle_resolves_target_by_player_id(t)
	local handler = MatchTransferHost()
	local queued = {}
	local target = {
		id = 2,
		token = "target-token",
		enqueue = function(self, data)
			table.insert(queued, data)
		end,
	}
	local match = {
		host_id = 1,
		slots = {},
	}
	for i = 0, 15 do
		match.slots[i] = {}
	end
	match.slots[1].player_id = 2

	local transferred_to
	local broadcasted
	match.broadcast = function(self, packet, players)
		broadcasted = packet
	end

	local player = {
		id = 1,
		match = match,
	}

	local server = {
		players = {
			_dict = nil,
			get = function(self, token, id)
				return id == 2 and target or nil
			end,
		},
		match_manager = {
			transferHost = function(self, _match, new_host)
				transferred_to = new_host
				_match.host_id = new_host.id
			end,
			buildMatchData = function(self, _match)
				return {
					id = 1,
					in_progress = false,
					powerplay = 0,
					mods = 0,
					name = "Test",
					passwd = "",
					map_name = "",
					map_id = 0,
					map_md5 = "",
					slot_statuses = {4},
					slot_teams = {0},
					slot_ids = {1},
					host_id = _match.host_id,
					mode = 0,
					win_condition = 0,
					team_type = 0,
					freemods = false,
					seed = 0,
				}
			end,
		},
	}

	handler:handle(server, player, {slot_id = 1})

	t:eq(transferred_to, target)
	t:eq(match.host_id, 2)
	t:eq(#queued, 1)
	t:ne(broadcasted, nil)
end

return test
