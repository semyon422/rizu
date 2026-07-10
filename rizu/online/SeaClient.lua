local class = require("class")
local delay = require("delay")
local socket_url = require("socket.url")
local thread = require("thread")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")

local WebsocketConnection = require("web.ws.WebsocketConnection")

local Subprotocol = require("web.ws.Subprotocol")

local WebsocketPeer = require("icc.WebsocketPeer")
local TaskHandler = require("icc.TaskHandler")
local RemoteHandler = require("icc.RemoteHandler")
local Remote = require("icc.Remote")

local ServerRemoteValidation = require("sea.app.remotes.ServerRemoteValidation")
local client_whitelist = require("sea.app.remotes.client_whitelist")

---@class rizu.SeaClient
---@operator call: rizu.SeaClient
local SeaClient = class()

SeaClient.reconnect_interval = 10
SeaClient.reconnect_initial_interval = 1
SeaClient.socket_timeout = 10
SeaClient.tls_verify = true
SeaClient.tls_cafile = "resources/certs/cacert.pem"
SeaClient.log = print

local resolve_host_async = thread.async(function(host)
	local socket = require("socket")
	return socket.dns.toip(host)
end)

---@param client rizu.OnlineClient
---@param client_remote sea.ClientRemote
function SeaClient:new(client, client_remote)
	self.client = client

	self.protocol = Subprotocol()
	self.remote_handler = RemoteHandler(client_remote, client_whitelist)

	self.disconnected_ws = {send = function() return nil, "not connected" end}
	local server_peer = WebsocketPeer(self.disconnected_ws)
	self.server_peer = server_peer

	local task_handler = TaskHandler(self.remote_handler, "client")
	self.task_handler = task_handler

	task_handler.timeout = 60

	local remote = Remote(self.task_handler, self.server_peer) --[[@as sea.ServerRemote]]
	remote = ServerRemoteValidation(remote)
	self.remote = remote

	local remote_context = {remote = remote}

	function self.protocol:text(payload, fin)
		if not fin then return end

		local msg = server_peer:decode(payload)
		if not msg then return end

		task_handler:handle(server_peer, remote_context, msg)
	end

	self.connected = false
end

---@return web.WebsocketConnection
function SeaClient:createWebsocketConnection()
	return WebsocketConnection({
		scheduler = self.scheduler,
		timeout = self.socket_timeout,
		ssl_params = self:getSslParams(),
		on_connected = function(connection)
			self.connected = true
			self.server_peer.ws = connection
		end,
	})
end

---@return web.SslParams
function SeaClient:getSslParams()
	local params = {
		mode = "client",
		protocol = "any",
		options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
		verify = "none",
	}
	if self.tls_verify then
		params.verify = "peer"
		params.cafile = self.tls_cafile
	end
	return params
end

function SeaClient:setDisconnected()
	self.connected = false
	self.server_peer.ws = self.disconnected_ws
	self.client:setUser()
end

---@param err string?
function SeaClient:closeWebsocket(err)
	self:setDisconnected()
	if self.ws_con then
		self.ws_con:close(err)
	end
end

---@return true?
---@return string?
function SeaClient:ping()
	local ok, err = self.ws_con:send("ping")
	if not ok then
		self:closeWebsocket(err)
		return nil, err
	end

	ok, err = pcall(self.remote.heartbeat, self.remote)
	if not ok then
		self:closeWebsocket(err)
		return nil, err
	end

	return true
end

---@param url string
---@return string?
---@return string?
function SeaClient:resolveConnectHost(url)
	local parsed_url, err = socket_url.parse(url)
	if not parsed_url then
		return nil, err
	end
	return resolve_host_async(parsed_url.host)
end

---@param url string
---@param on_connect function
function SeaClient:load(url, on_connect)
	self.url = url
	self.stopped = false

	self.scheduler = CosocketScheduler()
	self.ws_con = self:createWebsocketConnection()
	self.ws_con.protocol = self.protocol

	self.reconnect_thread = coroutine.create(function()
		local reconnect_delay = self.reconnect_initial_interval
		while not self.stopped do
			local state = self.ws_con:getState()
			if state ~= "open" then
				self:closeWebsocket("reconnecting")
				self:log("connecting to websocket")
				local connect_host
				local ok, err
				connect_host, err = self:resolveConnectHost(url)
				if self.stopped then
					break
				end
				ok = not not connect_host
				if ok then
					ok, err = self.ws_con:connect(url, connect_host)
				end
				if self.stopped then
					break
				end
				if not ok then
					self:log("connection failed", err)
					delay.sleep(reconnect_delay)
					reconnect_delay = math.min(reconnect_delay * 2, self.reconnect_interval)
				else
					reconnect_delay = self.reconnect_initial_interval
					self:log("connected")
					on_connect()
					if self.stopped then
						break
					end
					local user = self.remote:getUser()
					if self.stopped then
						break
					end
					self.client:setUser(user)
				end
			end
			delay.sleep(1)
		end
	end)
	assert(coroutine.resume(self.reconnect_thread))

	self.ping_thread = coroutine.create(function()
		while not self.stopped do
			local state = self.ws_con:getState()
			if state == "open" then
				self:ping()
			end
			delay.sleep(10)
		end
	end)
	assert(coroutine.resume(self.ping_thread))
end

function SeaClient:unload()
	if self.stopped then
		return
	end
	self.stopped = true
	self:closeWebsocket("unload")
end

function SeaClient:update()
	if self.ws_con then
		self.ws_con:update()
	end
end

return SeaClient
