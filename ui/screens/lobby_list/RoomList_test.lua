love.window.setMode(800, 600)

local RoomList = require("ui.screens.lobby_list.RoomList")

local test = {}

---@return sea.MultiplayerClient
local function createClient()
	return {
		getUser = function(_, id)
			if id == 2 then return {id = 2, name = "Host"} end
		end,
	} --[[@as sea.MultiplayerClient]]
end

---@param t testing.T
function test.resets_scroll_when_rooms_change(t)
	local list = RoomList(createClient())
	list:anchorFixed(0, 0, 500, 100)
	---@type sea.Room[]
	local rooms = {
		{id = 1, name = "One"},
		{id = 2, name = "Two"},
		{id = 3, name = "Three"},
	}
	list:setRooms(rooms)
	list:scrollTo(50, true)
	list:setRooms({{id = 4, name = "Four"}})

	t:eq(list:getItemCount(), 1)
	t:eq(list:getScrollPosition(), 0)
end

---@param t testing.T
function test.joins_clicked_room(t)
	local selected
	local list = RoomList(createClient(), function(room)
		selected = room
	end)
	list:anchorFixed(0, 0, 500, 100)
	list:setRooms({{id = 1, name = "One"}, {id = 2, name = "Two"}})
	local screen = require("gui.Screen")()
	screen.root:add(list)
	screen:resize(500, 100)

	list:onMouseClick({button = 1, x = 10, y = 90} --[[@as gui.MouseClickEvent]])
	t:eq(selected.id, 2)
end

return test
