#!/usr/bin/env luajit
--- Bancho CLI client.
---
--- Interactive REPL and one-shot command client for testing bancho servers.
---
--- Usage:
---   ./bancho/client/cli.lua                          # interactive REPL
---   ./bancho/client/cli.lua register <name> <email> <password>
---   ./bancho/client/cli.lua login <name> <password>
---   ./bancho/client/cli.lua login <name> <password> --host c.example.com --port 8091
---
--- Environment variables:
---   BANCHO_HOST       Server hostname (default: c.localhost)
---   BANCHO_PORT       Server port (default: 8180)
---   BANCHO_SCHEME     http or https (default: http)
---   BANCHO_USERNAME   Default username
---   BANCHO_PASSWORD   Default password (plaintext, auto-md5'd)

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

local BanchoClient = require("bancho.client.BanchoClient")
local ClientConfig = require("bancho.client.ClientConfig")
local Binary = require("bancho.protocol.Binary")
local PacketReader = require("bancho.protocol.PacketReader")
local ServerPackets = require("bancho.protocol.ServerPackets")
local ClientPackets = require("bancho.protocol.ClientPackets")
local HttpClient = require("web.http.HttpClient")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local http_util = require("web.http.util")
local json = require("web.json")
local md5 = require("md5")
local socket_url = require("socket.url")

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------

--- Packet name lookup table.
local packet_names = {}
for name, id in pairs(ServerPackets) do
	if type(id) == "number" then
		packet_names[id] = name
	end
end
for name, id in pairs(ClientPackets) do
	if type(id) == "number" then
		packet_names[id] = packet_names[id] or name
	end
end

--- Pretty print a single packet.
---@param pkt bancho.client.IncomingPacket
local function print_packet(pkt)
	local name = packet_names[pkt.id] or string.format("UNKNOWN(%d)", pkt.id)
	io.write(string.format("  [%-25s] len=%d", name, pkt.bodyLen))

	if pkt.id == ServerPackets.NOTIFICATION and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		io.write(string.format("  msg=%q", reader:readString()))
	elseif pkt.id == ServerPackets.USER_ID and pkt.bodyLen >= 4 then
		io.write(string.format("  user_id=%d", Binary.readI32(pkt.body, 1)))
	elseif pkt.id == ServerPackets.PRIVILEGES and pkt.bodyLen >= 4 then
		io.write(string.format("  priv=%d", Binary.readI32(pkt.body, 1)))
	elseif pkt.id == ServerPackets.PROTOCOL_VERSION and pkt.bodyLen >= 4 then
		io.write(string.format("  version=%d", Binary.readI32(pkt.body, 1)))
	elseif pkt.id == ServerPackets.CHANNEL_JOIN_SUCCESS and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		io.write(string.format("  channel=%q", reader:readString()))
	elseif pkt.id == ServerPackets.MATCH_JOIN_FAIL then
		io.write("  (failed)")
	elseif pkt.id == ServerPackets.MATCH_JOIN_SUCCESS and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local match_id = reader:readI32()
		local match_name = reader:readString()
		io.write(string.format("  match_id=%d name=%q", match_id, match_name))
	elseif pkt.id == ServerPackets.NEW_MATCH and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local match_id = reader:readI32()
		local match_name = reader:readString()
		io.write(string.format("  match_id=%d name=%q", match_id, match_name))
	elseif pkt.id == ServerPackets.SEND_MESSAGE and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local sender = reader:readString()
		local text = reader:readString()
		local recipient = reader:readString()
		local sender_id = reader:readI32()
		io.write(string.format("  from=%s(%d) to=%s text=%q", sender, sender_id, recipient, text))
	elseif pkt.id == ServerPackets.UPDATE_MATCH and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local match_id = reader:readI32()
		local match_name = reader:readString()
		io.write(string.format("  match_id=%d name=%q", match_id, match_name))
	elseif pkt.id == ServerPackets.DISPOSE_MATCH and pkt.bodyLen >= 4 then
		io.write(string.format("  match_id=%d", Binary.readI32(pkt.body, 1)))
	elseif pkt.id == ServerPackets.MATCH_START and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local match_id = reader:readI32()
		io.write(string.format("  match_id=%d", match_id))
	elseif pkt.id == ServerPackets.MATCH_COMPLETE then
		io.write("  (completed)")
	elseif pkt.id == ServerPackets.MATCH_TRANSFER_HOST then
		io.write("  (host transferred)")
	elseif pkt.id == ServerPackets.MATCH_SKIP then
		io.write("  (skipped)")
	elseif pkt.id == ServerPackets.MATCH_ALL_PLAYERS_LOADED then
		io.write("  (all loaded)")
	elseif pkt.id == ServerPackets.CHANNEL_INFO and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local chan_name = reader:readString()
		local topic = reader:readString()
		local pcount = reader:readU16()
		io.write(string.format("  channel=%q topic=%q players=%d", chan_name, topic, pcount))
	elseif pkt.id == ServerPackets.USER_PRESENCE and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local uid = reader:readI32()
		local uname = reader:readString()
		io.write(string.format("  user_id=%d name=%q", uid, uname))
	elseif pkt.id == ServerPackets.USER_STATS and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local uid = reader:readI32()
		local action = reader:readU8()
		local info = reader:readString()
		io.write(string.format("  user_id=%d action=%d info=%q", uid, action, info))
	elseif pkt.id == ServerPackets.FRIENDS_LIST and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local friends = reader:readI32List()
		io.write(string.format("  count=%d", #friends))
	elseif pkt.id == ServerPackets.SILENCE_END and pkt.bodyLen >= 4 then
		io.write(string.format("  remaining=%ds", Binary.readI32(pkt.body, 1)))
	elseif pkt.id == ServerPackets.CHANNEL_AUTO_JOIN and pkt.bodyLen > 0 then
		local reader = PacketReader(pkt.body)
		local chan_name = reader:readString()
		io.write(string.format("  channel=%q", chan_name))
	elseif pkt.id == ServerPackets.PONG then
		io.write("  (pong)")
	end
	io.write("\n")
end

--- Print response packets with summary.
---@param packets bancho.client.IncomingPacket[]
local function print_response(packets)
	if #packets == 0 then
		io.write("  (no response)\n")
		return
	end
	io.write(string.format("  <- %d packet(s):\n", #packets))
	for _, pkt in ipairs(packets) do
		print_packet(pkt)
	end
end

--- Send command and print result.
---@param client bancho.client.BanchoClient
---@param fn fun(client): bancho.client.IncomingPacket[], string?
local function exec(client, fn)
	local packets, err = fn(client)
	if err then
		io.write(string.format("  ERROR: %s\n", err))
		return
	end
	print_response(packets)
end

--- Do an HTTP request and print result.
---@param method string
---@param url string
---@param headers table<string, string>
---@param body string?
local function http_request(method, url, headers, body)
	local client = HttpClient(LsTcpSocket())
	client.tcp_soc:settimeout(10)

	local req, res = client:connect(url)
	req.method = method
	for k, v in pairs(headers) do
		req.headers:set(k, v)
	end
	if body then
		req.headers:set("Content-Length", #body)
		req:send(body)
	end

	local resp_body, err = res:receive("*a")
	client:close()

	if err then
		io.write(string.format("  HTTP ERROR: %s\n", err))
		return
	end

	io.write(string.format("  HTTP %d\n", res.status))
	if res.headers:get("Content-Type") and res.headers:get("Content-Type"):find("json") then
		local data = json.decode(resp_body)
		io.write(string.format("  %s\n", json.encode(data, { indent = true })))
	elseif #resp_body > 0 and #resp_body < 500 then
		io.write(string.format("  %s\n", resp_body))
	elseif #resp_body >= 500 then
		io.write(string.format("  (%d bytes)\n", #resp_body))
	else
		io.write("  (empty)\n")
	end
end

--- Build config from args and env.
local function build_config(args)
	local host = args.host or os.getenv("BANCHO_HOST") or "c.localhost"
	local port = tonumber(args.port or os.getenv("BANCHO_PORT") or "8180")
	local scheme = args.scheme or os.getenv("BANCHO_SCHEME") or "http"
	if host == "c.localhost" then
		scheme = "http"
	end
	return ClientConfig {
		host = host,
		port = port,
		scheme = scheme,
	}
end

-- ------------------------------------------------------------------
-- Commands
-- ------------------------------------------------------------------

--- Register a new account.
---@param args table
local function cmd_register(args)
	local username = args[1]
	local email = args[2]
	local password = args[3]

	if not username or not email or not password then
		io.write("Usage: register <username> <email> <password>\n")
		return
	end

	local config = build_config(args)
	local osu_host = config.host:gsub("^c[.]", "osu.")
	local url = string.format("%s://%s:%s/users", config.scheme, osu_host, config.port)
	local body = string.format(
		"user[username]=%s&user[user_email]=%s&user[password]=%s&check=0",
		socket_url.escape(username),
		socket_url.escape(email),
		socket_url.escape(password)
	)

	io.write(string.format("Registering %s@%s on %s...\n", username, email, url))
	http_request("POST", url, {
		["Content-Type"] = "application/x-www-form-urlencoded",
		["User-Agent"] = "osu!",
	}, body)
end

-- ------------------------------------------------------------------
-- REPL helpers (must come before cmd_login)
-- ------------------------------------------------------------------

--- Parse a command line into name + args.
---@param line string
---@return string name
---@return string[] args
local function parse_command(line)
	line = line:match("^%s*(.-)%s*$")
	if #line == 0 or line:sub(1, 1) == "#" then
		return "", {}
	end

	local parts = {}
	for word in line:gmatch("[^%s]+") do
		table.insert(parts, word)
	end
	return parts[1], { unpack(parts, 2) }
end

--- Handle a command string. Returns false if session should end.
---@param client bancho.client.BanchoClient
---@param cmd string
---@return boolean continue
local function handle_command(client, cmd)
	local name, args = parse_command(cmd)

	if name == "help" then
		print([[
Commands:
  help                    Show this help
  quit / exit             Disconnect and exit

  chat join <channel>     Join a channel (#general, #mania, etc.)
  chat part <channel>     Leave a channel
  chat send <channel> <msg>  Send message to channel
  chat pm <user> <msg>    Send private message

  match create <name> [pw]  Create a match
  match join <id> [pw]      Join a match
  match part                Leave current match
  match ready               Ready up
  match not-ready           Not ready
  match lock [on|off]       Lock/unlock match
  match start               Start match countdown
  match skip                Request skip
  match transfer-host       Transfer host
  match mods <bitmask>      Change mods
  match team <team>         Change team (0-3)
  match password <pw>       Change match password
  match invite <user>       Invite user
  match load-complete       Signal beatmap loaded
  match has-beatmap         Signal you have the beatmap
  match no-beatmap          Signal you don't have it
  match complete            Signal play complete
  match failed              Signal play failed
  lobby join                Join multiplayer lobby
  lobby part                Leave multiplayer lobby

  spectate <user_id>        Start spectating
  spectate stop             Stop spectating

  status <action> [text] [md5] [mods] [map_id]
                            Update status (action: 0=idle, 1=playing, 2=editing, 3=multi)
  away <message>            Set away message (empty to clear)
  ping                      Send ping

  friend add <user>         Add friend
  friend remove <user>      Remove friend

  stats <user_id>           Request user stats
  presence <user>           Request user presence
  presence all              Request all presences
  updates <mode> <on|off>   Toggle presence updates

  http get <url>            HTTP GET request
  http post <url> <body>    HTTP POST request
  register <name> <email> <pw>  Register account
  login <name> <pw>         Login (reconnects)

  packets                   List known packet IDs
  raw <hex>                 Send raw hex packet
]])
		return true
	end

	if name == "quit" or name == "exit" then
		client:logout()
		io.write("Logged out.\n")
		return false
	end

	if name == "chat" then
		if args[1] == "join" then
			exec(client, function(c) return c:join_channel(args[2]) end)
		elseif args[1] == "part" then
			exec(client, function(c) return c:part_channel(args[2]) end)
		elseif args[1] == "send" then
			exec(client, function(c) return c:send_message(args[2], table.concat(args, " ", 3)) end)
		elseif args[1] == "pm" then
			exec(client, function(c) return c:send_private_message(args[2], table.concat(args, " ", 3)) end)
		else
			io.write("Usage: chat join|part|send|pm ...\n")
		end
		return true
	end

	if name == "match" then
		if args[1] == "create" then
			exec(client, function(c) return c:create_match(args[2], args[3] or "") end)
		elseif args[1] == "join" then
			exec(client, function(c) return c:join_match(tonumber(args[2]), args[3] or "") end)
		elseif args[1] == "part" then
			exec(client, function(c) return c:part_match() end)
		elseif args[1] == "ready" then
			exec(client, function(c) return c:match_ready() end)
		elseif args[1] == "not-ready" then
			exec(client, function(c) return c:match_not_ready() end)
		elseif args[1] == "lock" then
			local locked = args[2] == nil or args[2] == "on"
			exec(client, function(c) return c:match_lock(locked) end)
		elseif args[1] == "start" then
			exec(client, function(c) return c:match_start() end)
		elseif args[1] == "skip" then
			exec(client, function(c) return c:match_skip() end)
		elseif args[1] == "transfer-host" then
			exec(client, function(c) return c:match_transfer_host() end)
		elseif args[1] == "mods" then
			exec(client, function(c) return c:match_change_mods(tonumber(args[2]) or 0) end)
		elseif args[1] == "team" then
			exec(client, function(c) return c:match_change_team(tonumber(args[2]) or 0) end)
		elseif args[1] == "password" then
			exec(client, function(c) return c:match_change_password(args[2] or "") end)
		elseif args[1] == "invite" then
			exec(client, function(c) return c:match_invite(args[2]) end)
		elseif args[1] == "load-complete" then
			exec(client, function(c) return c:match_load_complete() end)
		elseif args[1] == "has-beatmap" then
			exec(client, function(c) return c:match_has_beatmap() end)
		elseif args[1] == "no-beatmap" then
			exec(client, function(c) return c:match_no_beatmap() end)
		elseif args[1] == "complete" then
			exec(client, function(c) return c:match_complete() end)
		elseif args[1] == "failed" then
			exec(client, function(c) return c:match_failed() end)
		else
			io.write("Usage: match create|join|part|ready|lock|start|skip ...\n")
		end
		return true
	end

	if name == "lobby" then
		if args[1] == "join" then
			exec(client, function(c) return c:join_lobby() end)
		elseif args[1] == "part" then
			exec(client, function(c) return c:part_lobby() end)
		else
			io.write("Usage: lobby join|part\n")
		end
		return true
	end

	if name == "spectate" then
		if args[1] == "stop" then
			exec(client, function(c) return c:stop_spectating() end)
		else
			exec(client, function(c) return c:start_spectating(tonumber(args[1])) end)
		end
		return true
	end

	if name == "status" then
		local action = tonumber(args[1]) or 0
		local info_text = args[2] or ""
		local map_md5 = args[3] or ""
		local mods = tonumber(args[4]) or 0
		local map_id = tonumber(args[5]) or 0
		exec(client, function(c) return c:update_status(0, action, info_text, map_md5, mods, map_id) end)
		return true
	end

	if name == "away" then
		exec(client, function(c) return c:set_away_message(table.concat(args, " ")) end)
		return true
	end

	if name == "ping" then
		exec(client, function(c) return c:ping() end)
		return true
	end

	if name == "friend" then
		if args[1] == "add" then
			exec(client, function(c) return c:add_friend(args[2]) end)
		elseif args[1] == "remove" then
			exec(client, function(c) return c:remove_friend(args[2]) end)
		else
			io.write("Usage: friend add|remove <user>\n")
		end
		return true
	end

	if name == "stats" then
		exec(client, function(c) return c:request_user_stats(tonumber(args[1])) end)
		return true
	end

	if name == "presence" then
		if args[1] == "all" then
			exec(client, function(c) return c:request_all_presences() end)
		else
			exec(client, function(c) return c:request_user_presence(args[1]) end)
		end
		return true
	end

	if name == "updates" then
		local mode = tonumber(args[1]) or 0
		local enabled = args[2] == "on"
		exec(client, function(c) return c:receive_updates(mode, enabled) end)
		return true
	end

	if name == "http" then
		if args[1] == "get" then
			io.write(string.format("GET %s\n", args[2]))
			http_request("GET", args[2], { ["User-Agent"] = "osu!" }, nil)
		elseif args[1] == "post" then
			io.write(string.format("POST %s\n", args[2]))
			http_request("POST", args[2], {
				["User-Agent"] = "osu!",
				["Content-Type"] = "application/x-www-form-urlencoded",
			}, table.concat(args, " ", 3))
		else
			io.write("Usage: http get|post <url> ...\n")
		end
		return true
	end

	if name == "register" then
		cmd_register({ username = args[1], email = args[2], password = args[3], host = args.host })
		return true
	end

	if name == "login" then
		cmd_login({ args[1], args[2], host = args.host })
		return true
	end

	if name == "packets" then
		io.write("Server packets:\n")
		for id = 0, 120 do
			local n = packet_names[id]
			if n then
				io.write(string.format("  %3d  %s\n", id, n))
			end
		end
		return true
	end

	if name == "raw" then
		local hex_str = table.concat(args, "")
		local data = {}
		for byte in hex_str:gmatch("..") do
			table.insert(data, tonumber(byte, 16))
		end
		local binary = string.char(unpack(data))
		exec(client, function(c) return c:send(binary) end)
		return true
	end

	io.write(string.format("Unknown command: %s (type 'help' for commands)\n", name))
	return true
end

--- Start interactive REPL.
---@param client bancho.client.BanchoClient
local function start_repl(client)
	io.write("\n=== Bancho REPL (type 'help' for commands) ===\n")
	while true do
		io.write("> ")
		io.flush()
		local line = io.read("*l")
		if not line then
			break
		end

		line = line:gsub('"([^"]*)"', function(m) return m:gsub(" ", "\1") end)
		local name, args = parse_command(line)
		if name ~= "" then
			for i = 1, #args do
				args[i] = (args[i]:gsub("\1", " "))
			end
			local cont = handle_command(client, name .. " " .. table.concat(args, " "))
			if not cont then
				break
			end
		end
	end
end

--- Login and stay connected (for REPL).
---@param args table
local function cmd_login(args)
	local username = args[1]
	local password = args[2]

	if not username or not password then
		io.write("Usage: login <username> <password>\n")
		return
	end

	local config = build_config(args)
	config.username = username
	config.password_md5 = md5.sumhexa(password)

	local client = BanchoClient(config)
	io.write(string.format("Logging in as %s...\n", username))
	local result = client:login()

	if result.success then
		io.write(string.format("Logged in! user_id=%d\n", result.user_id))
		print_response(result.packets)
		return start_repl(client)
	else
		io.write(string.format("Login failed: %s\n", result.error))
		print_response(result.packets)
	end
end

--- One-shot send (reads username/password from env).
---@param args table
local function cmd_send(args)
	local command = table.concat(args, " ")
	if not command or #command:trim() == 0 then
		io.write("Usage: send <command> [args...]\n")
		return
	end

	local username = os.getenv("BANCHO_USERNAME")
	local password = os.getenv("BANCHO_PASSWORD")
	if not username or not password then
		io.write("Set BANCHO_USERNAME and BANCHO_PASSWORD env vars, or use 'login' first.\n")
		return
	end

	local config = build_config(args)
	config.username = username
	config.password_md5 = md5.sumhexa(password)

	local client = BanchoClient(config)
	local result = client:login()
	if not result.success then
		io.write(string.format("Login failed: %s\n", result.error))
		return
	end

	io.write(string.format("Logged in as user_id=%d\n", result.user_id))
	local ok = handle_command(client, command)
	if not ok then
		client:logout()
	end
end

-- ------------------------------------------------------------------
-- Main
-- ------------------------------------------------------------------

local function main()
	local args = { unpack(arg or {}) }

	if #args == 0 then
		io.write("=== Bancho CLI ===\n")
		io.write("Usage: cli.lua <command> [args...]\n\n")
		io.write("Commands:\n")
		io.write("  register <username> <email> <password>  Register a new account\n")
		io.write("  login <username> <password>             Login and enter REPL\n")
		io.write("  send <command>                          One-shot command (needs BANCHO_USERNAME/PASSWORD)\n")
		io.write("\nOptions: --host <h> --port <p> --scheme <http|https>\n")
		io.write("\nExamples:\n")
		io.write("  ./bancho/client/cli.lua register testuser test@test.com mypassword123\n")
		io.write("  ./bancho/client/cli.lua login testuser mypassword123\n")
		io.write("  ./bancho/client/cli.lua login testuser mypassword123 --host c.dfjk.ru --port 443 --scheme https\n")
		return
	end

	-- Parse global options
	local command = args[1]
	local remaining = { unpack(args, 2) }
	local options = {}

	-- Extract --key value pairs
	local filtered = {}
	for i = 1, #remaining do
		if remaining[i]:sub(1, 2) == "--" then
			local key = remaining[i]:sub(3)
			local val = remaining[i + 1]
			if val and val:sub(1, 2) ~= "--" then
				options[key] = val
				i = i + 1
			else
				options[key] = true
			end
		else
			table.insert(filtered, remaining[i])
		end
	end

	-- Inject options into args for config builders
	for k, v in pairs(options) do
		filtered[k] = v
	end

	if command == "register" then
		cmd_register({ unpack(filtered) })
	elseif command == "login" then
		cmd_login({ unpack(filtered) })
	elseif command == "send" then
		cmd_send({ unpack(filtered) })
	else
		io.write(string.format("Unknown command: %s\n", command))
		io.write("Use 'cli.lua' without args for help.\n")
	end
end

main()
