--- Bancho Reftest Shared Infrastructure
---
--- Shared helpers, server configs, and test framework for reference server testing.
--- Each test file exports `function M.run(srv, c1, c2)` called by run.lua.

local M = {}

-- ============================================================================
-- Module setup (called once by run.lua)
-- ============================================================================

function M.setup_modules()
	local pkg = require("aqua.pkg")
	pkg.addc()
	pkg.addc("3rd-deps/lib")
	pkg.addc("bin/lib")
	pkg.addc("tree/lib/lua/5.1")
	pkg.add()
	pkg.add("3rd-deps/lua")
	pkg.add("aqua")
	pkg.add("ncdk")
	pkg.add("chartbase")
	pkg.add("libchart")
	pkg.add("tree/share/lua/5.1")
	pkg.export_lua()
end

-- Lazy-load heavy deps only when needed.
local BanchoClient, ClientConfig, Binary, PacketReader, ServerPackets, HttpClient, LsTcpSocket, md5, socket_url

function M.ensure_deps()
	if BanchoClient then return end
	BanchoClient = require("bancho.client.BanchoClient")
	ClientConfig = require("bancho.client.ClientConfig")
	Binary = require("bancho.protocol.Binary")
	PacketReader = require("bancho.protocol.PacketReader")
	ServerPackets = require("bancho.protocol.ServerPackets")
	HttpClient = require("web.http.HttpClient")
	LsTcpSocket = require("web.luasocket.LsTcpSocket")
	md5 = require("md5")
	socket_url = require("socket.url")

	-- Export for test files.
	M.BanchoClient = BanchoClient
	M.ClientConfig = ClientConfig
	M.Binary = Binary
	M.PacketReader = PacketReader
	M.ServerPackets = ServerPackets
	M.HttpClient = HttpClient
	M.LsTcpSocket = LsTcpSocket
	M.md5 = md5
	M.socket_url = socket_url
end

-- ============================================================================
-- Test framework
-- ============================================================================

M.results = {}
M.current_server = nil
M.test_num = 0

--- Record a test result.
function M.record(name, status, detail)
	M.test_num = M.test_num + 1
	table.insert(M.results, { name = name, server = M.current_server, status = status, detail = detail or "" })
	io.write(string.format("  [%s] %-30s %s %s\n", status, name, M.current_server, detail or ""))
end

-- ============================================================================
-- HTTP helpers
-- ============================================================================

--- HTTP GET request.
function M.http_get(url, headers)
	M.ensure_deps()
	headers = headers or {}
	local client = HttpClient(LsTcpSocket())
	client.tcp_soc:settimeout(15)
	local req, res = client:connect(url)
	req.method = "GET"
	for k, v in pairs(headers) do
		req.headers:set(k, v)
	end
	req:send("")
	local body = res:receive("*a")
	client:close()
	return res.status, body or ""
end

--- HTTP POST request.
function M.http_post(url, body, headers)
	M.ensure_deps()
	headers = headers or {}
	headers["Content-Type"] = "application/x-www-form-urlencoded"
	local client = HttpClient(LsTcpSocket())
	client.tcp_soc:settimeout(15)
	local req, res = client:connect(url)
	req.method = "POST"
	req.headers:set("Content-Length", #body)
	for k, v in pairs(headers) do
		req.headers:set(k, v)
	end
	req:send(body)
	local resp = res:receive("*a")
	client:close()
	return res.status, resp or ""
end

-- ============================================================================
-- Server configurations
-- ============================================================================

M.servers = {
	{
		name = "our_server",
		host = "c.localhost",
		port = 8180,
		scheme = "http",
		osu_host = "osu.localhost",
	},
	{
		name = "bancho.py",
		host = "c.dfjk.ru",
		port = 443,
		scheme = "https",
		osu_host = "osu.dfjk.ru",
	},
}

-- ============================================================================
-- Helpers
-- ============================================================================

local test_counter = 0
local ts_suffix = tostring(os.time()):sub(-2) .. tostring(os.time()):sub(-3, -3)

--- Create a unique username (max 15 chars for osu!).
function M.unique_name(prefix)
	test_counter = test_counter + 1
	local name = prefix .. ts_suffix .. test_counter .. math.random(0, 9)
	return string.sub(name, 1, 15)
end

--- Register a user on a server.
--- Returns username, email, password or nil, nil, nil, error.
function M.register_user(srv)
	M.ensure_deps()
	local username = M.unique_name("t")
	local email = username .. "@t.com"
	local password = "testpass123"

	local url = string.format("%s://%s:%s/users", srv.scheme, srv.osu_host, srv.port)
	local body = string.format(
		"user[username]=%s&user[user_email]=%s&user[password]=%s&check=0",
		socket_url.escape(username),
		socket_url.escape(email),
		socket_url.escape(password)
	)

	local ok, err = pcall(function()
		local status, resp_body = M.http_post(url, body, { ["User-Agent"] = "osu!" })
		if status ~= 200 or (resp_body ~= "ok" and not resp_body:find('"ok"')) then
			error(string.format("HTTP %d: %s", status, tostring(resp_body):sub(1, 200)))
		end
	end)

	if not ok then
		return nil, nil, nil, err
	end
	return username, email, password
end

--- Create a BanchoClient and login.
--- Returns client, user_id or nil, nil, error.
function M.login(srv, username, password)
	M.ensure_deps()
	local config = ClientConfig {
		host = srv.host,
		port = srv.port,
		scheme = srv.scheme,
		username = username,
		password_md5 = md5.sumhexa(password),
	}
	local client = BanchoClient(config)
	local result = client:login()
	if not result.success then
		return nil, nil, result.error or "login failed"
	end
	return client, result.user_id, nil
end

--- Find a packet by ID.
function M.find_pkt(packets, id)
	for _, p in ipairs(packets) do
		if p.id == id then return p end
	end
	return nil
end

--- Extract match ID from response packets.
function M.get_match_id(packets)
	M.ensure_deps()
	local pkt = M.find_pkt(packets, ServerPackets.MATCH_JOIN_SUCCESS)
	if pkt then return Binary.readU16(pkt.body, 1) end
	return nil
end

--- Extract channel name from CHANNEL_JOIN_SUCCESS.
function M.get_channel_name(packets)
	M.ensure_deps()
	local pkt = M.find_pkt(packets, ServerPackets.CHANNEL_JOIN_SUCCESS)
	if pkt then return PacketReader(pkt.body):readString() end
	return nil
end

--- Extract message text from SEND_MESSAGE.
function M.get_message(packets)
	M.ensure_deps()
	local pkt = M.find_pkt(packets, ServerPackets.SEND_MESSAGE)
	if pkt then
		local ComplexTypes = require("bancho.protocol.ComplexTypes")
		return ComplexTypes.readMessage(PacketReader(pkt.body)).text
	end
	return nil
end

return M
