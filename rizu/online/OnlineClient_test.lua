local OnlineClient = require("rizu.online.OnlineClient")

local test = {}

---@param t testing.T
function test.emits_user_changes(t)
	local client = OnlineClient()
	local events = {}
	local observer = client:onChanged(function(event)
		table.insert(events, event)
	end)
	local user = {id = 1, name = "player"}

	client:setUser(user --[[@as sea.User]])
	client:setUser(user --[[@as sea.User]])
	client:setUser()

	t:eq(#events, 2)
	t:eq(events[1].type, "user_changed")
	t:eq(events[1].user, user)
	t:eq(events[2].type, "user_changed")
	t:eq(events[2].user, nil)

	client:offChanged(observer)
	client:setUser(user --[[@as sea.User]])
	t:eq(#events, 2)
end

---@param t testing.T
function test.emits_connection_changes(t)
	local client = OnlineClient()
	local events = {}
	client:onChanged(function(event)
		table.insert(events, event)
	end)

	client:setConnected(true)
	client:setConnected(true)
	client:setConnected(false)

	t:eq(#events, 2)
	t:tdeq(events[1], {type = "connection_changed", connected = true})
	t:tdeq(events[2], {type = "connection_changed", connected = false})
end

return test
