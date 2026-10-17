--- Fake HTTP transport for E2E tests.
---
--- Uses real Request/Response objects backed by ExtendedStringSocket
--- to simulate HTTP without real networking.
--- Each method call creates a new server instance (simulating a new worker).

local ExtendedStringSocket = require("bancho.e2e.ExtendedStringSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")
local PacketReader = require("bancho.protocol.PacketReader")

local class = require("class")

--- Fake HTTP transport.
--- Directly calls BanchoProtocolResource methods using real HTTP objects
--- backed by ExtendedStringSocket pairs.
---@class bancho.e2e.FakeHttpTransport: bancho.client.IHttpTransport
---@operator call: bancho.e2e.FakeHttpTransport
---@field config bancho.client.ClientConfig
---@field resource_factory fun(): bancho.http.BanchoProtocolResource
---@field token string?
local FakeHttpTransport = class()

---@param config bancho.client.ClientConfig
---@param resource_factory fun(): bancho.http.BanchoProtocolResource
function FakeHttpTransport:new(config, resource_factory)
	self.config = config
	self.resource_factory = resource_factory
	return self
end

--- Build the request body string with headers.
---@param body string
---@param extra_headers {[string]: string}
---@return string
local function build_request(body, extra_headers)
	local lines = {}
	table.insert(lines, "POST / HTTP/1.1")
	table.insert(lines, "Host: osu.example.com")
	table.insert(lines, "Content-Length: " .. #body)

	for name, value in pairs(extra_headers) do
		table.insert(lines, name .. ": " .. value)
	end

	table.insert(lines, "") -- blank line separates headers from body
	table.insert(lines, body)

	return table.concat(lines, "\r\n")
end

--- Parse HTTP response to extract just the body.
---@param raw string raw HTTP response
---@return string body
local function extract_body(raw)
	local header_end = raw:find("\r\n\r\n")
	if not header_end then
		return ""
	end
	return raw:sub(header_end + 4)
end

--- Create a Request/Response pair for a POST request.
---
--- StringSocket pairs work such that send(A) -> data appears in pair(A).
--- So we send request data to res_soc so it appears in req_soc (for Request to read).
--- Response writes to res_soc so data appears in req_soc (for us to read).
---
---@param body string
---@param extra_headers {[string]: string}
---@return web.Request
---@return web.Response
---@return bancho.e2e.ExtendedStringSocket read_socket socket to read response from
local function create_request_response(body, extra_headers)
	-- Create socket pair
	local req_soc = ExtendedStringSocket()
	local res_soc = req_soc:split()

	-- Send request data to res_soc so it appears in req_soc (for Request to read)
	local request_str = build_request(body, extra_headers)
	res_soc:send(request_str)

	-- Create real Request/Response objects
	local req = Request(req_soc, "r")
	local res = Response(res_soc, "w")

	-- Response writes to res_soc, data appears in req_soc for us to read
	return req, res, req_soc
end

--- Login and parse response packets.
---@return bancho.client.IncomingPacket[] packets
---@return string? error
function FakeHttpTransport:login_and_parse()
	local resource = self.resource_factory()

	-- Use config's login_body() for correct format
	local login_body = self.config:login_body()

	local req, res, read_soc = create_request_response(login_body, {})
	resource:handleProtocol(req, res)

	-- Extract body from HTTP response
	local raw = read_soc.soc.remainder or ""
	local body = extract_body(raw)
	self.token = res.headers:get("cho-token")

	return self:parse_packets(body)
end

--- Send packet data and parse response.
---@param data string
---@return bancho.client.IncomingPacket[] packets
---@return string? error
function FakeHttpTransport:send_and_parse(data)
	local resource = self.resource_factory()

	local headers = {}
	if self.token then
		headers["osu-token"] = self.token
	end

	local req, res, read_soc = create_request_response(data, headers)
	resource:handleProtocol(req, res)

	local raw = read_soc.soc.remainder or ""
	local body = extract_body(raw)
	return self:parse_packets(body)
end

--- Parse binary packet data into a list of packets.
---@param data string
---@return bancho.client.IncomingPacket[]
function FakeHttpTransport:parse_packets(data)
	local packets = {}
	if not data or #data == 0 then
		return packets
	end

	local reader = PacketReader(data)
	while reader:hasMore() do
		local header = reader:readHeader()
		if not header then
			break
		end

		local body = ""
		if header.bodyLen > 0 then
			body = reader:readBytes(header.bodyLen) or ""
		end

		table.insert(packets, {
			id = header.id,
			body = body,
		})
	end

	return packets
end

return FakeHttpTransport
