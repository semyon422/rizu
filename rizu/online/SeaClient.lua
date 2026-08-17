local class = require("class")
local delay = require("delay")

local Subprotocol = require("web.ws.Subprotocol")

local WebsocketPeer = require("icc.WebsocketPeer")
local TaskHandler = require("icc.TaskHandler")
local RemoteHandler = require("icc.RemoteHandler")
local Remote = require("icc.Remote")

local ServerRemoteValidation = require("sea.app.remotes.ServerRemoteValidation")
local client_whitelist = require("sea.app.remotes.client_whitelist")

---@class rizu.SeaClient
---@operator call: rizu.SeaClient
---@field network rizu.NetworkService
---@field pending_returns icc.Message[]
local SeaClient = class()

SeaClient.reconnect_interval = 10
SeaClient.reconnect_initial_interval = 1
SeaClient.log = print

---@param client rizu.OnlineClient
---@param client_remote sea.ClientRemote
---@param network rizu.NetworkService
function SeaClient:new(client, client_remote, network)
	self.client = client
	self.network = assert(network, "network is required")
	self.pending_returns = {}

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
	local sea_client = self

	function self.protocol:text(payload, fin)
		if not fin then return end

		local msg = server_peer:decode(payload)
		if not msg then return end

		if msg.ret then
			table.insert(sea_client.pending_returns, msg)
		else
			task_handler:handle(server_peer, remote_context, msg)
		end
	end

	self.connected = false
end

---@return web.WebsocketConnection
function SeaClient:createWebsocketConnection()
	return self.network:createWebsocketConnection({
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
	return self.network:resolveUrl(url)
end

---@param url string
---@param on_connect function
function SeaClient:load(url, on_connect)
	self.url = url
	self.stopped = false

	self.ws_con = self:createWebsocketConnection()
	self.ws_con.protocol = self.protocol

	self.reconnect_thread = coroutine.create(function()
		local reconnect_delay = self.reconnect_initial_interval
		while not self.stopped do
			local state = self.ws_con:getState()
			if state ~= "open" then
				self:closeWebsocket("reconnecting")
				self:log("connecting to websocket")
				local ok, err
				ok, err = self.network:connectWebsocket(self.ws_con, url)
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

function SeaClient:update()
	local pending_returns = self.pending_returns
	self.pending_returns = {}
	for _, msg in ipairs(pending_returns) do
		self.task_handler:handleReturn(msg)
	end
	self.task_handler:update()
end

function SeaClient:unload()
	if self.stopped then
		return
	end
	self.stopped = true
	self:closeWebsocket("unload")
end

return SeaClient
