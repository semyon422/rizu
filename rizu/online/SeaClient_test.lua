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
---@field send_error string?
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
---@param connect_host string?
---@return true?
---@return string?
function FakeWebsocketConnection:connect(url, connect_host)
	table.insert(self.events, "connect:" .. url .. ":" .. tostring(connect_host))
	if not self.connect_ok then
		return nil, "connect failed"
	end
	self.state = "open"
	if self.on_connected then
		self.on_connected(self)
	end
	self:startReader()
	return true
end

---@param err string?
---@return 1
function FakeWebsocketConnection:close(err)
	table.insert(self.events, "close:" .. tostring(err))
	self.state = "closed"
	return 1
end

---@return integer?
---@return string?
function FakeWebsocketConnection:send()
	table.insert(self.events, "send")
	if self.send_error then
		return nil, self.send_error
	end
	return 1
end

function FakeWebsocketConnection:update()
	table.insert(self.events, "update")
end

function FakeWebsocketConnection:startReader()
	table.insert(self.events, "startReader")
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
		connection.on_connected = function(_connection)
			self.connected = true
			self.server_peer.ws = _connection
		end
		return connection --[[@as any]]
	end
	function sea_client:resolveConnectHost(url)
		return "203.0.113.10"
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
		"connect:ws://example.test/ws:203.0.113.10",
		"startReader",
		"send",
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
		"connect:ws://example.test/ws:203.0.113.10",
	})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:tdeq(client.users, table_util.pack(nil))
end

---@param t testing.T
function test.failed_dns_does_not_connect(t)
	local connection = new_connection(true)
	local client = new_client()
	local sea_client = SeaClient(client, {})
	sea_client.threaded = false
	sea_client.log = function() end
	function sea_client:createWebsocketConnection()
		return connection --[[@as any]]
	end
	function sea_client:resolveConnectHost()
		return nil, "dns failed"
	end

	sea_client:load("ws://example.test/ws", function() end)

	t:tdeq(connection.events, {"close:reconnecting"})
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

---@param t testing.T
function test.ping_send_failure_disconnects(t)
	local connection = new_connection(true)
	local sea_client, client = load_client(connection, {id = 1})

	connection.events = {}
	connection.send_error = "send failed"

	t:tdeq({sea_client:ping()}, {nil, "send failed"})

	t:tdeq(connection.events, {
		"send",
		"close:send failed",
	})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:eq(client.users[client.users.n], nil)
end

---@param t testing.T
function test.ping_heartbeat_failure_disconnects(t)
	local connection = new_connection(true)
	local sea_client, client = load_client(connection, {id = 1})
	sea_client.remote.heartbeat = function()
		error("heartbeat failed")
	end

	connection.events = {}

	local ok, err = sea_client:ping()

	t:eq(ok, nil)
	t:assert(tostring(err):find("heartbeat failed", 1, true))
	t:tdeq(connection.events, {
		"send",
		"close:" .. tostring(err),
	})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:eq(client.users[client.users.n], nil)
end

return test
