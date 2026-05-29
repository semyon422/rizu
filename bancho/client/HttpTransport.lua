--- HTTP transport for the Bancho protocol.
---
--- Implements the bancho protocol over HTTP POST requests:
--- - Login: POST / without osu-token header (body = credentials)
--- - Packet exchange: POST / with osu-token header (body = binary packets)

local HttpClient = require("web.http.HttpClient")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local Binary = require("bancho.protocol.Binary")
local PacketReader = require("bancho.protocol.PacketReader")

local class = require("class")

--- Represents a single parsed packet from the server response.
---@class bancho.client.IncomingPacket
---@field id integer Packet ID
---@field body string Raw body bytes
---@field bodyLen integer Body length

--- HTTP transport layer for bancho protocol.
---@class bancho.client.HttpTransport
---@operator call: bancho.client.HttpTransport
---@field config bancho.client.ClientConfig
---@field token string? Connection token (set after login)
local HttpTransport = class()

---@param config bancho.client.ClientConfig
function HttpTransport:new(config)
	self.config = config
	self.token = nil
	return self
end

--- Send a login request and return the response.
---@return string? body Raw response body
---@return string? error Error message
function HttpTransport:login()
	local client = HttpClient(LsTcpSocket())
	client.tcp_soc:settimeout(self.config.timeout)

	local req, res = client:connect(self.config:url())

	req.method = "POST"
	req.headers:set("User-Agent", "osu!")
	req.headers:set("Content-Length", #self.config:login_body())

	local _, err = req:send(self.config:login_body())
	if err then
		client:close()
		return nil, "send error: " .. err
	end

	local body, recv_err, partial = res:receive("*a")
	-- Use partial data if main body is nil (e.g., connection closed early)
	if body == nil and partial then
		body = partial
	end
	if body == nil and recv_err and recv_err ~= "closed" then
		client:close()
		return nil, "receive error: " .. recv_err
	end

	local cho_token = res.headers:get("cho-token")
	if cho_token and cho_token ~= "" then
		self.token = cho_token
	end

	client:close()
	return body or "", nil
end

--- Send binary packet data to the server and return the response.
--- Requires a valid token from a previous login.
---@param data string Binary packet data
---@return string? body Raw response body
---@return string? error Error message
function HttpTransport:send(data)
	if not self.token then
		return nil, "not logged in"
	end

	local client = HttpClient(LsTcpSocket())
	client.tcp_soc:settimeout(self.config.timeout)

	local req, res = client:connect(self.config:url())

	req.method = "POST"
	req.headers:set("User-Agent", "osu!")
	req.headers:set("osu-token", self.token)
	req.headers:set("Content-Length", #data)

	local _, err = req:send(data)
	if err then
		client:close()
		return nil, "send error: " .. err
	end

	local body, recv_err, partial = res:receive("*a")
	-- Use partial data if main body is nil (e.g., connection closed early)
	if body == nil and partial then
		body = partial
	end
	if body == nil and recv_err and recv_err ~= "closed" then
		client:close()
		return nil, "receive error: " .. recv_err
	end
	if body == nil then
		body = ""
	end

	client:close()
	return body, nil
end

--- Parse raw response body into individual packets.
---@param body string Raw binary response
---@return bancho.client.IncomingPacket[]
function HttpTransport:parse_packets(body)
	if not body or #body == 0 then
		return {}
	end

	local packets = {}
	local reader = PacketReader(body)

	while reader:hasMore() do
		local header = reader:readHeader()
		if not header then
			break
		end

		table.insert(packets, {
			id = header.id,
			bodyLen = header.bodyLen,
			body = reader:readBytes(header.bodyLen),
		})
	end

	return packets
end

--- Send login and return parsed packets.
---@return bancho.client.IncomingPacket[]
---@return string? error
function HttpTransport:login_and_parse()
	local body, err = self:login()
	if err then
		return {}, err
	end
	return self:parse_packets(body or ""), nil
end

--- Send packets and return parsed response.
---@param data string Binary packet data
---@return bancho.client.IncomingPacket[]
---@return string? error
function HttpTransport:send_and_parse(data)
	local body, err = self:send(data)
	if err then
		return {}, err
	end
	return self:parse_packets(body or ""), nil
end

return HttpTransport
