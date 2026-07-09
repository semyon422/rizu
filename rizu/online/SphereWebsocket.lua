local class = require("class")
local Websocket = require("web.ws.Websocket")
local ws_util = require("web.ws.util")
local Subprotocol = require("web.ws.Subprotocol")

---@class rizu.SphereWebsocketOptions
---@field scheduler web.CosocketScheduler?
---@field tcp_socket web.ITcpSocket?
---@field ip_version 4|6?

---@class rizu.SphereWebsocket
---@operator call: rizu.SphereWebsocket
---@field options rizu.SphereWebsocketOptions
---@field scheduler web.CosocketScheduler?
local SphereWebsocket = class()

---@param options rizu.SphereWebsocketOptions?
function SphereWebsocket:new(options)
	self.protocol = Subprotocol()
	self.options = options or {}
	self.scheduler = self.options.scheduler
end

---@param url string
---@return true?
---@return string?
function SphereWebsocket:connect(url)
	local ws_client = ws_util.client(self.options)
	self.soc = ws_client.tcp_soc

	local re, err = ws_client:connect(url)
	if not re then
		return nil, err
	end

	local ws = Websocket(self.soc, re.req, re.res, "client")
	self.ws = ws
	ws.protocol = self.protocol
	ws.max_payload_len = 1e7

	local ok
	ok, err = ws:handshake()
	if not ok then
		return nil, err
	end

	self:startReader()

	return true
end

---@return web.WebsocketState
function SphereWebsocket:getState()
	local ws = self.ws
	return ws and ws:getState() or "connecting"
end

function SphereWebsocket:startReader()
	if not self.scheduler then
		return
	end

	self.reader_thread = coroutine.create(function()
		local ws = self.ws
		while ws and ws:getState() == "open" do
			local state = ws:getState()
			local ok, err = ws:step()
			if not ok then
				if state ~= "closed" then
					print(("websocket error: %s"):format(err))
				end
				break
			end
		end
	end)
	assert(coroutine.resume(self.reader_thread))
end

function SphereWebsocket:update()
	local scheduler = self.scheduler
	if scheduler then
		local ok, err = scheduler:update(0)
		if not ok and err then
			print(("cosocket scheduler error: %s"):format(err))
		end
		return
	end

	local soc = self.soc
	local ws = self.ws
	if not soc or not ws then
		return
	end
	while soc:selectreceive(0) do
		local state = ws:getState()
		local ok, err = ws:step()
		if not ok then
			if state ~= "closed" then
				print(("websocket error: %s"):format(err))
			end
			break
		end
	end
end

return SphereWebsocket
