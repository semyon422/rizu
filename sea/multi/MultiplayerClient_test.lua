local MultiplayerClient = require("sea.multi.MultiplayerClient")

local test = {}

---@param t testing.T
function test.emits_room_list_changes(t)
	local client = MultiplayerClient()
	local events = {}
	local observer = client:onChanged(function(event)
		table.insert(events, event)
	end)
	---@type sea.Room[]
	local rooms = {{id = 1, name = "Room"}}

	client:setRooms(rooms)

	t:eq(#events, 1)
	t:eq(events[1].type, "rooms_changed")
	t:eq(events[1].rooms, rooms)

	client:offChanged(observer)
	client:setRooms({})
	t:eq(#events, 1)
end

---@param t testing.T
function test.emits_room_membership_changes(t)
	local client = MultiplayerClient()
	local events = {}
	client:onChanged(function(event)
		table.insert(events, event)
	end)

	---@type sea.RoomUser[]
	local room_users = {{room_id = 7, user_id = 3}}
	client:setRoomUsers(room_users)
	t:eq(client.room_id, 7)
	t:eq(events[1].type, "room_users_changed")
	t:eq(events[1].room_id, 7)

	client:setRoomUsers({})
	t:eq(client.room_id, nil)
	t:eq(events[2].room_id, nil)
end

---@param t testing.T
function test.emits_join_failure(t)
	local client = MultiplayerClient({
		multiplayer = {
			joinRoom = function()
				return nil, "invalid password"
			end,
		},
	})
	local event
	client:onChanged(function(received)
		event = received
	end)

	client:joinRoomAsync(4, "bad")

	t:eq(event.type, "join_failed")
	t:eq(event.room_id, 4)
	t:eq(event.error, "invalid password")
end

return test
