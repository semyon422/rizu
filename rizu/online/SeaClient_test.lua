local SeaClient = require("rizu.online.SeaClient")
local delay = require("delay")
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
---@field after_connect fun(connection: rizu.FakeWebsocketConnection)?
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
	if self.after_connect then
		self.after_connect(self)
	end
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

---@class rizu.FakeNetworkService
---@field connect_host string?
---@field connect_error string?
---@field before_connect fun(network: rizu.FakeNetworkService)?
local FakeNetworkService = {}
FakeNetworkService.__index = FakeNetworkService

---@return rizu.FakeNetworkService
local function new_network()
	return setmetatable({
		connect_host = "203.0.113.10",
	}, FakeNetworkService)
end

---@param connection rizu.FakeWebsocketConnection
---@param url string
---@return true?
---@return string?
function FakeNetworkService:connectWebsocket(connection, url)
	if self.before_connect then
		self:before_connect()
	end
	if self.connect_error then
		return nil, self.connect_error
	end
	return connection:connect(url, self.connect_host)
end

function FakeNetworkService:update()
	return true
end

---@param options web.WebsocketClientOptions
---@return table
function FakeNetworkService:createWebsocketConnection(options)
	return {options = options}
end

---@param connection rizu.FakeWebsocketConnection
---@param user any?
---@return rizu.SeaClient
---@return rizu.FakeOnlineClient
local function load_client(connection, user)
	local client = new_client()
	local sea_client = SeaClient(client, {}, new_network() --[[@as any]])
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
function test.failed_reconnect_uses_backoff(t)
	local original_sleep = delay.sleep
	---@type number[]
	local sleeps = {}

	local connection = new_connection(false)
	local client = new_client()
	local sea_client = SeaClient(client, {}, new_network() --[[@as any]])

	local ok, err = pcall(function()
		delay.sleep = function(duration)
			if coroutine.running() == sea_client.reconnect_thread then
				table.insert(sleeps, duration)
			end
			return coroutine.yield()
		end

		sea_client.log = function() end
		sea_client.reconnect_initial_interval = 1
		sea_client.reconnect_interval = 4
		function sea_client:createWebsocketConnection()
			return connection --[[@as any]]
		end

		sea_client:load("ws://example.test/ws", function() end)
		assert(coroutine.resume(sea_client.reconnect_thread))
		assert(coroutine.resume(sea_client.reconnect_thread))
		assert(coroutine.resume(sea_client.reconnect_thread))
		assert(coroutine.resume(sea_client.reconnect_thread))
		assert(coroutine.resume(sea_client.reconnect_thread))
		assert(coroutine.resume(sea_client.reconnect_thread))

		t:eq(sleeps[1], 1)
		t:eq(sleeps[3], 2)
		t:eq(sleeps[5], 4)
		t:eq(sleeps[7], 4)
	end)
	delay.sleep = original_sleep
	if not ok then
		error(err, 0)
	end
end

---@param t testing.T
function test.failed_dns_does_not_connect(t)
	local connection = new_connection(true)
	local client = new_client()
	local network = new_network()
	network.connect_error = "dns failed"
	local sea_client = SeaClient(client, {}, network --[[@as any]])
	sea_client.log = function() end
	function sea_client:createWebsocketConnection()
		return connection --[[@as any]]
	end

	sea_client:load("ws://example.test/ws", function() end)

	t:tdeq(connection.events, {"close:reconnecting"})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:tdeq(client.users, table_util.pack(nil))
end

---@param t testing.T
function test.failed_reconnect_logs_context_without_url_query(t)
	local connection = new_connection(true)
	local client = new_client()
	local network = new_network()
	network.connect_error = "bad websocket status: HTTP 503, server=edge.test"
	local sea_client = SeaClient(client, {}, network --[[@as any]])
	local logs = {}
	sea_client.log = function(_, message)
		table.insert(logs, message)
	end
	function sea_client:createWebsocketConnection()
		return connection --[[@as any]]
	end

	sea_client:load("wss://example.test/ws?token=secret", function() end)

	t:tdeq(logs, {
		"connecting url=wss://example.test/ws attempt=1",
		"connection failed url=wss://example.test/ws attempt=1 error=bad websocket status: HTTP 503, server=edge.test retry_in=1s",
	})
end

---@param t testing.T
function test.stopped_after_dns_does_not_connect(t)
	local connection = new_connection(true)
	local client = new_client()
	local network = new_network()
	local sea_client = SeaClient(client, {}, network --[[@as any]])
	network.before_connect = function()
		sea_client.stopped = true
		network.connect_error = "dns failed"
	end
	sea_client.log = function() end
	function sea_client:createWebsocketConnection()
		return connection --[[@as any]]
	end

	sea_client:load("ws://example.test/ws", function()
		error("on_connect should not be called")
	end)

	t:tdeq(connection.events, {"close:reconnecting"})
	t:eq(sea_client.connected, false)
	t:eq(sea_client.server_peer.ws, sea_client.disconnected_ws)
	t:tdeq(client.users, table_util.pack(nil))
end

---@param t testing.T
function test.stopped_after_connect_skips_user_sync(t)
	local connection = new_connection(true)
	local client = new_client()
	local sea_client = SeaClient(client, {}, new_network() --[[@as any]])
	sea_client.log = function() end
	sea_client.remote = {
		getUser = function()
			error("getUser should not be called")
		end,
		heartbeat = function() end,
	}
	function sea_client:createWebsocketConnection()
		connection.on_connected = function(_connection)
			self.connected = true
			self.server_peer.ws = _connection
		end
		connection.after_connect = function()
			self.stopped = true
		end
		return connection --[[@as any]]
	end

	sea_client:load("ws://example.test/ws", function()
		error("on_connect should not be called")
	end)

	t:tdeq(connection.events, {
		"close:reconnecting",
		"connect:ws://example.test/ws:203.0.113.10",
		"startReader",
	})
	t:eq(sea_client.connected, true)
	t:eq(sea_client.server_peer.ws, connection)
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

---@param t testing.T
function test.create_websocket_connection_passes_transport_policy(t)
	local network = new_network()
	function network:createWebsocketConnection(options)
		options.timeout = 3
		options.ssl_params = {verify = "none"}
		return {options = options}
	end
	local sea_client = SeaClient(new_client(), {}, network --[[@as any]])

	local connection = sea_client:createWebsocketConnection()

	t:eq(connection.options.timeout, 3)
	t:eq(connection.options.ssl_params.verify, "none")
	t:eq(type(connection.options.on_status), "function")
end

---@param t testing.T
function test.network_status_logs_dns_and_connect_route(t)
	local logs = {}
	local sea_client = SeaClient(new_client(), {}, new_network() --[[@as any]])
	sea_client.log = function(_, message)
		table.insert(logs, message)
	end

	sea_client:onNetworkStatus({state = "dns", host = "example.test", cached = true, ip = "203.0.113.10"})
	sea_client:onNetworkStatus({state = "connecting", ip = "203.0.113.10"})

	t:tdeq(logs, {
		"dns host=example.test cached=true ip=203.0.113.10",
		"transport connecting ip=203.0.113.10",
	})
end

---@param t testing.T
function test.network_is_required(t)
	t:has_error(function()
		SeaClient(new_client(), {})
	end, "network is required")
end

return test
