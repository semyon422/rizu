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
		on_connected = function(connection)
			self.connected = true
			self.server_peer.ws = connection
		end,
	})
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
		while not self.stopped do
			local state = self.ws_con:getState()
			if state ~= "open" then
				self:closeWebsocket("reconnecting")
				self:log("connecting to websocket")
				local connect_host
				local ok, err
				connect_host, err = self:resolveConnectHost(url)
				ok = not not connect_host
				if ok then
					ok, err = self.ws_con:connect(url, connect_host)
				end
				if not ok then
					self:log("connection failed", err)
					delay.sleep(self.reconnect_interval)
				else
					self:log("connected")
					on_connect()
					self.client:setUser(self.remote:getUser())
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
