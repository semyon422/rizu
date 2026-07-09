local SeaClient = require("rizu.online.SeaClient")
local table_util = require("table_util")

local test = {}

---@class rizu.FakeOnlineClient
---@field users any[]
local FakeOnlineClient = {}
FakeOnlineClient.__index = FakeOnlineClient

---@return rizu.FakeOnlineClient
local function new_client()
	return setmetatable({users = {n = 0}}, FakeOnlineClient)
end

---@param user any?
function FakeOnlineClient:setUser(user)
	local users = self.users
	users.n = users.n + 1
	users[users.n] = user
end

---@class rizu.FakeWebsocketConnection
---@field state web.WebsocketState
---@field events string[]
---@field connect_ok boolean
local FakeWebsocketConnection = {}
FakeWebsocketConnection.__index = FakeWebsocketConnection

---@param connect_ok boolean
---@return rizu.FakeWebsocketConnection
local function new_connection(connect_ok)
	return setmetatable({
		state = "closed",
		events = {},
		connect_ok = connect_ok,
	}, FakeWebsocketConnection)
end

---@return web.WebsocketState
function FakeWebsocketConnection:getState()
	return self.state
end

---@param url string
---@return true?
---@return string?
function FakeWebsocketConnection:connect(url)
	table.insert(self.events, "connect:" .. url)
	if not self.connect_ok then
		return nil, "connect failed"
	end
	self.state = "open"
	return true
end

---@param err string?
---@return 1
function FakeWebsocketConnection:close(err)
	table.insert(self.events, "close:" .. tostring(err))
	self.state = "closed"
	return 1
end

---@return integer
function FakeWebsocketConnection:send()
	return 1
end

function FakeWebsocketConnection:update()
	table.insert(self.events, "update")
end

---@param connection rizu.FakeWebsocketConnection
---@param user any?
---@return rizu.SeaClient
---@return rizu.FakeOnlineClient
local function load_client(connection, user)
	local client = new_client()
	local sea_client = SeaClient(client, {})
	sea_client.threaded = false
	sea_client.log = function() end
	sea_client.remote = {
		getUser = function()
			return user
		end,
		heartbeat = function() end,
	}
	function sea_client:createWebsocketConnection()
		return connection --[[@as any]]
	end
	sea_client:load("ws://example.test/ws", function() end)
	return sea_client, client
end

---@param t testing.T
function test.main_thread_connect_replaces_disconnected_peer(t)
	local user = {id = 1}
	local connection = new_connection(true)
	local sea_client, client = load_client(connection, user)

	t:tdeq(connection.events, {
		"close:reconnecting",
		"connect:ws://example.test/ws",
	})
	t:eq(sea_client.connected, true)
	t:eq(sea_client.server_peer.ws, connection)
	t:tdeq(client.users, table_util.pack(nil, user))
end

---@param t testing.T
function test.failed_reconnect_keeps_disconnected_peer(t)
	local connection = new_connection(false)
	local sea_client, client = load_client(connection)

	t:tdeq(connection.events, {
		"close:reconnecting",
		"connect:ws://example.test/ws",
	})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:tdeq(client.users, table_util.pack(nil))
end

---@param t testing.T
function test.unload_closes_main_thread_connection(t)
	local connection = new_connection(true)
	local sea_client, client = load_client(connection, {id = 1})

	connection.events = {}
	sea_client:unload()

	t:tdeq(connection.events, {"close:unload"})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.stopped, true)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:eq(client.users[client.users.n], nil)
end

return test
