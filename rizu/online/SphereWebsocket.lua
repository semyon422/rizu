local class = require("class")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local Websocket = require("web.ws.Websocket")
local WebsocketClient = require("web.ws.WebsocketClient")
local Subprotocol = require("web.ws.Subprotocol")

---@class rizu.SphereWebsocket
---@operator call: rizu.SphereWebsocket
local SphereWebsocket = class()

function SphereWebsocket:new()
	self.protocol = Subprotocol()
end

---@param url string
---@return true?
---@return string?
function SphereWebsocket:connect(url)
	self.soc = LsTcpSocket(4)

	local ws_client = WebsocketClient(self.soc)
	local re, err = ws_client:connect(url)
	if not re then
		return nil, err
	end

	local ws = Websocket(self.soc, re.req, re.res, "client")
	self.ws = ws
	ws.protocol = self.protocol
	ws.max_payload_len = 1e7

	return ws:handshake()
end

---@return web.WebsocketState
function SphereWebsocket:getState()
	local ws = self.ws
	return ws and ws:getState() or "connecting"
end

function SphereWebsocket:update()
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
