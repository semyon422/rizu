--- Bancho protocol HTTP resource.
---
--- Handles the osu! client Bancho protocol over HTTP POST.
--- Login: POST / without osu-token header (body = credentials)
--- Packet exchange: POST / with osu-token header (body = binary packets)
---
--- Also serves debug pages: GET /, /online, /matches.

local IResource = require("web.framework.IResource")
local ServerPackets = require("bancho.protocol.ServerPackets")
local ClientPackets = require("bancho.protocol.ClientPackets")
local PacketReader = require("bancho.protocol.PacketReader")
local Binary = require("bancho.protocol.Binary")
local LoginHandler = require("bancho.auth.LoginHandler")
local GameMode = require("bancho.constants.GameMode")
local Privileges = require("bancho.constants.Privileges")
local ClientPrivileges = require("bancho.constants.ClientPrivileges")
local BcryptHasher = require("sea.access.BcryptPasswordHasher")

local json = require("web.json")
local http_util = require("web.http.util")

---@class bancho.http.BanchoProtocolResource: web.IResource
---@operator call: bancho.http.BanchoProtocolResource
---@field server bancho.server.BanchoServer
local BanchoProtocolResource = IResource + {}

BanchoProtocolResource.routes = {
	{"/", {
		GET = "getStatus",
		POST = "handleProtocol",
	}},
	{"/online", {
		GET = "getOnline",
	}},
	{"/matches", {
		GET = "getMatches",
	}},
}

--- Domains that serve the Bancho protocol.
--- Matches osu.{domain}, c.{domain}, c4.{domain}, etc.
BanchoProtocolResource.domains = {
	"osu.*",
	"c.*",
	"ce.*",
	"c4.*",
	"c5.*",
	"c6.*",
}

---@param server bancho.server.BanchoServer
function BanchoProtocolResource:new(server)
	self.server = server
	self.bcrypt = BcryptHasher()
end

--- GET / — Status page showing server info.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function BanchoProtocolResource:getStatus(req, res, ctx)
	local players = self.server.players
	local matches = self.server.matches
	local all_packets = ClientPackets

	local player_list = players:all()
	local match_list = matches:all()
	local non_bot_count = 0
	for _, p in ipairs(player_list) do
		if p.id ~= self.server.config.bot_id then
			non_bot_count = non_bot_count + 1
		end
	end

	local body = ([[
<!DOCTYPE html>
<body style="font-family: monospace; white-space: pre-wrap;">
Running bancho server

<a href="online">%d online players</a>
<a href="matches">%d matches</a>

<b>packets handled (%d)</b>
%s
</body>
</html>
		]])
		:format(
			non_bot_count,
			#match_list,
			#all_packets,
			""
		)

	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res:send(body)
end

--- GET /online — Debug page listing online players.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function BanchoProtocolResource:getOnline(req, res, ctx)
	local players = self.server.players:all()

	---@type string[]
	local user_lines = {}
	---@type string[]
	local bot_lines = {}

	for _, p in ipairs(players) do
		local line = string.format("(%d): %s", p.id, p.name)
		if p.id == self.server.config.bot_id then
			table.insert(bot_lines, line)
		else
			table.insert(user_lines, line)
		end
	end

	local body = ([[
<!DOCTYPE html>
<body style="font-family: monospace; white-space: pre-wrap;">
<a href="/">back</a>
users:
%s
bots:
%s
</body>
</html>
		]])
		:format(
			table.concat(user_lines, "\n"),
			table.concat(bot_lines, "\n")
		)

	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res:send(body)
end

--- GET /matches — Debug page listing active matches.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function BanchoProtocolResource:getMatches(req, res, ctx)
	local match_list = self.server.matches:all()

	---@type string[]
	local match_lines = {}
	for _, m in ipairs(match_list) do
		local status = m.in_progress and "ongoing" or "idle"
		local line = string.format(
			"%s (%d): %s\n-- beatmap: %s\n-- host: %s",
			status,
			m.id,
			m.name or "",
			m.map_name or "",
			m.host_id and tostring(m.host_id) or ""
		)
		table.insert(match_lines, line)
	end

	local body = ([[
<!DOCTYPE html>
<body style="font-family: monospace; white-space: pre-wrap;">
<a href="/">back</a>
matches:
%s
</body>
</html>
		]])
		:format(table.concat(match_lines, "\n"))

	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res:send(body)
end

--- POST / — Bancho protocol handler.
--- Without osu-token: login attempt.
--- With osu-token: packet exchange for authenticated player.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function BanchoProtocolResource:handleProtocol(req, res, ctx)
	-- Read the full request body
	local body, err = req:receive("*a")
	if not body then
		res.status = 400
		res:send(err or "failed to read body")
		return
	end

	-- Check for osu-token header
	local osu_token = req.headers:get("osu-token")

	if not osu_token or osu_token == "" then
		-- Login attempt
		self:handleLogin(body, res, ctx)
	else
		-- Packet exchange
		self:handlePackets(osu_token, body, res, ctx)
	end
end

--- Handle a login request.
--- Body format: username\npassword_md5\nosu_version|utc_offset|...|pm_private\n
---@param body string
---@param res web.IResponse
---@param ctx sea.RequestContext
function BanchoProtocolResource:handleLogin(body, res, ctx)
	local result = LoginHandler.parse(body)

	if not result.ok then
		local response_body = ServerPackets.loginReply(result.failure_reason or -1)
		res.headers:set("cho-token", "invalid-request")
		res:send(response_body)
		return
	end

	local login_data = result.data
	local server = self.server

	-- Validate client data
	if not server.login_handler:validate(login_data) then
		local response_body = ServerPackets.loginReply(-1)
			.. ServerPackets.notification("Please restart your osu! and try again.")
		res.headers:set("cho-token", "invalid-request")
		res:send(response_body)
		return
	end

	-- Authenticate against user repository
	if not server.user_repo then
		local response_body = ServerPackets.loginReply(-5)
			.. ServerPackets.notification("Server error: no user repository configured")
		res.headers:set("cho-token", "error")
		res:send(response_body)
		return
	end

	-- Look up user by name and password
	local user = server.user_repo:findUserByNameAndPassword(login_data.username, login_data.password_md5)
	if not user then
		local response_body = ServerPackets.notification(server.config.domain .. ": Incorrect credentials")
			.. ServerPackets.loginReply(-1)
		res.headers:set("cho-token", "incorrect-credentials")
		res:send(response_body)
		return
	end

	-- Check if already logged in
	local existing = server.players:get(nil, user.id)
	if existing then
		server.players:remove(existing)
	end

	-- Create player instance
	local Player = require("bancho.model.Player")
	local player = Player(user.id, login_data.username, user.priv or 0)
	player.is_online = true
	player.utc_offset = login_data.utc_offset or 0

	-- Add player to collection
	server.players:add(player)

	-- Build login response
	local data = ServerPackets.protocolVersion(19)
	data = data .. ServerPackets.loginReply(player.id)
	data = data .. ServerPackets.banchoPrivileges(bit.bor(player:bancho_priv(), ClientPrivileges.SUPPORTER))
	data = data .. ServerPackets.notification("Welcome back to " .. server.config.domain .. "!")

	-- Channel info
	for _, channel in ipairs(server.channels:all()) do
		if channel.auto_join then
			data = data .. ServerPackets.channelInfo(channel.name, channel.topic or "", #channel.players)
		end
	end
	data = data .. ServerPackets.channelInfoEnd()

	-- Friends list
	local friends = {}
	if server.friends_repo then
		friends = server.friends_repo:getFriends(player.id)
	end
	data = data .. ServerPackets.friendsList(friends)

	-- User presence and stats for this player
	local mode = player.status.mode
	local stats = player.stats[mode] or player.stats[0]
	data = data .. ServerPackets.userPresence(
		player.id,
		player.name,
		player.utc_offset or 0,
		0, -- country code (TODO)
		bit.bor(player:bancho_priv(), bit.lshift(mode, 5)),
		0, -- longitude
		0, -- latitude
		stats.rank
	)
	data = data .. ServerPackets.userStats(
		player.id,
		player.status.action,
		player.status.info_text or "",
		player.status.map_md5 or "",
		player.status.mods,
		mode,
		player.status.map_id or 0,
		stats.rscore,
		stats.acc,
		stats.plays,
		stats.tscore,
		stats.rank,
		stats.pp
	)

	-- Broadcast presence to other players
	local presence_data = ServerPackets.userPresence(
		player.id,
		player.name,
		player.utc_offset or 0,
		0,
		bit.bor(player:bancho_priv(), bit.lshift(mode, 5)),
		0,
		0,
		stats.rank
	)
	local stats_data = ServerPackets.userStats(
		player.id,
		player.status.action,
		player.status.info_text or "",
		player.status.map_md5 or "",
		player.status.mods,
		mode,
		player.status.map_id or 0,
		stats.rscore,
		stats.acc,
		stats.plays,
		stats.tscore,
		stats.rank,
		stats.pp
	)

	server.players:enqueue(presence_data .. stats_data, {player})

	-- Send presence of other players to the new player
	for _, other in ipairs(server.players:all()) do
		if other.id ~= player.id then
			local other_mode = other.status.mode
			local other_stats = other.stats[other_mode] or other.stats[0]
			data = data .. ServerPackets.userPresence(
				other.id,
				other.name,
				other.utc_offset or 0,
				0,
				bit.bor(other:bancho_priv(), bit.lshift(other_mode, 5)),
				0,
				0,
				other_stats.rank
			)
			data = data .. ServerPackets.userStats(
				other.id,
				other.status.action,
				other.status.info_text or "",
				other.status.map_md5 or "",
				other.status.mods,
				other_mode,
				other.status.map_id or 0,
				other_stats.rscore,
				other_stats.acc,
				other_stats.plays,
				other_stats.tscore,
				other_stats.rank,
				other_stats.pp
			)
		end
	end

	res.headers:set("cho-token", player.token)
	res:send(data)
end

--- Handle packet exchange for an authenticated player.
---@param token string
---@param body string binary packet data
---@param res web.IResponse
---@param ctx sea.RequestContext
function BanchoProtocolResource:handlePackets(token, body, res, ctx)
	local player = self.server.players:get(token)

	if not player then
		-- Server restarted or token invalid — tell client to reconnect
		res:send(
			ServerPackets.notification("Server has restarted.")
			.. ServerPackets.restartServer(0)
		)
		return
	end

	-- Process incoming packets
	if #body > 0 then
		self.server:processPackets(player, body)
	end

	-- Drain player's outgoing packet queue
	local response_data = player:dequeue()
	res:send(response_data)
end

return BanchoProtocolResource
