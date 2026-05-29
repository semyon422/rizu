--- osu! client web API endpoints.
---
--- These endpoints are called by the osu! client for score submission,
--- leaderboards, beatmap info, friends, and other in-game features.

local IResource = require("web.framework.IResource")
local http_util = require("web.http.util")
local json = require("web.json")
local ScoreCrypto = require("bancho.crypto.ScoreCrypto")
local Score = require("bancho.model.Score")
local RankedStatus = require("bancho.constants.RankedStatus")
local SubmissionStatus = require("bancho.constants.SubmissionStatus")
local GameMode = require("bancho.constants.GameMode")
local Mods = require("bancho.constants.Mods")
local Grade = require("bancho.constants.Grade")
local ClientFlags = require("bancho.constants.ClientFlags")

local socket_url = require("socket.url")

--- Helper to send JSON response.
---@param res web.IResponse
---@param data any
local function util_send_json(res, data)
	res.headers:set("Content-Type", "application/json")
	res:send(json.encode(data))
end

---@class bancho.http.OsuWebResource: web.IResource
---@operator call: bancho.http.OsuWebResource
---@field server bancho.server.BanchoServer
local OsuWebResource = IResource + {}

OsuWebResource.routes = {
	-- Score submission
	{"/web/osu-submit-modular.php", {
		POST = "osuSubmitModular",
	}},
	{"/web/osu-submit-modular-selector.php", {
		POST = "osuSubmitModularSelector",
	}},

	-- Leaderboards
	{"/web/osu-osz2-getscores.php", {
		GET = "osuGetscores",
	}},

	-- Replays
	{"/web/osu-getreplay.php", {
		GET = "osuGetReplay",
	}},

	-- Friends
	{"/web/osu-getfriends.php", {
		POST = "osuGetFriends",
	}},

	-- Beatmap info
	{"/web/osu-getbeatmapinfo.php", {
		POST = "osuGetBeatmapInfo",
	}},

	-- Beatmap search
	{"/web/osu-search.php", {
		GET = "osuSearch",
	}},
	{"/web/osu-search-set.php", {
		GET = "osuSearchSet",
	}},

	-- Favourites
	{"/web/osu-getfavourites.php", {
		GET = "osuGetFavourites",
	}},
	{"/web/osu-addfavourite.php", {
		GET = "osuAddFavourite",
	}},

	-- Anti-cheat
	{"/web/lastfm.php", {
		GET = "lastFm",
	}},

	-- Screenshots
	{"/web/osu-screenshot.php", {
		POST = "osuScreenshot",
	}},

	-- Ratings
	{"/web/osu-rate.php", {
		GET = "osuRate",
	}},

	-- Comments
	{"/web/osu-comment.php", {
		POST = "osuComment",
	}},

	-- Mail
	{"/web/osu-markasread.php", {
		GET = "osuMarkAsRead",
	}},

	-- Seasonal
	{"/web/osu-getseasonal.php", {
		GET = "osuGetSeasonal",
	}},

	-- Connection checks
	{"/web/bancho_connect.php", {
		GET = "banchoConnect",
	}},
	{"/web/check-updates.php", {
		GET = "checkUpdates",
	}},
}

--- Domains that serve osu! web API endpoints.
OsuWebResource.domains = {"osu.*"}

---@param server bancho.server.BanchoServer
function OsuWebResource:new(server)
	self.server = server
end

--- Authenticate a player from form/query params.
---@param req web.IRequest
---@param u_alias string username parameter alias (default "u")
---@param h_alias string password parameter alias (default "h")
---@return bancho.model.Player?
---@return string? error message
function OsuWebResource:authenticatePlayer(req, u_alias, h_alias)
	u_alias = u_alias or "u"
	h_alias = h_alias or "h"

	local username, password_md5
	local content_type = req.headers:get("Content-Type") or ""

	if content_type:find("multipart") then
		-- For multipart, we need to parse differently
		return nil, "multipart auth not yet supported"
	elseif content_type:find("application/x-www-form-urlencoded") then
		local body, err = req:receive("*a")
		if not body then
			return nil, err
		end
		local params = http_util.decode_query_string(body)
		username = params[u_alias]
		password_md5 = params[h_alias]
	else
		-- Try query string
		return nil, "no auth params"
	end

	if not username or not password_md5 then
		return nil, "missing auth params"
	end

	username = socket_url.unescape(username)
	return self:lookupPlayer(username, password_md5)
end

--- Look up an online player by name and password.
---@param username string
---@param password_md5 string
---@return bancho.model.Player?
function OsuWebResource:lookupPlayer(username, password_md5)
	-- First check online players
	local player = self.server.players:get(nil, nil, username)
	if player then
		-- Verify password matches stored hash
		if self.server.user_repo then
			local user = self.server.user_repo:findUserByNameAndPassword(username, password_md5)
			if user then
				return player
			end
		else
			return player
		end
	end
	return nil
end

-------------------------------------------------------------------
-- Score Submission
-------------------------------------------------------------------

--- POST /web/osu-submit-modular.php
--- Score submission with encrypted score data.
--- Authenticated via password (u, p params in score data).
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuSubmitModular(req, res, ctx)
	local multipart, err = http_util.get_multipart(req)
	if not multipart then
		res.status = 400
		res:send(err or "invalid multipart")
		return
	end

	-- Parse multipart form fields
	local fields = {}
	local score_parts = {}

	multipart:receive_preamble()

	local headers, err = multipart:receive()
	while headers and err ~= "no parts" do
		local part_data = multipart.bsoc:receiveany(1024 * 1024)
		if part_data then
			-- Extract field name from Content-Disposition
			local disp = headers:get("Content-Disposition") or ""
			local field_name = disp:match('name="([^"]+)"')
			if field_name then
				if field_name == "score" then
					-- score field appears twice: encrypted data + replay file
					table.insert(score_parts, part_data)
				else
					fields[field_name] = part_data
				end
			end
		end

		headers, err = multipart:receive()
	end

	-- Extract score data and replay
	if #score_parts < 2 then
		res:send("")
		return
	end

	local score_data_b64 = score_parts[1]
	local replay_data = score_parts[2]

	-- Decrypt score data
	local iv = fields.iv or ""
	local osuver = fields.osuver or ""
	local client_hash_b64 = fields.s or ""

	local score_crypto = ScoreCrypto:new()
	local score_data, client_hash = score_crypto:decryptScore(score_data_b64, client_hash_b64, iv, osuver)
	if not score_data then
		res:send("")
		return
	end

	-- Parse score data (colon-delimited)
	local parts = {}
	for part in score_data:gmatch("[^:]+") do
		parts[#parts + 1] = part
	end

	-- Minimum fields check: map_md5, username, n300, n100, n50, ngeki, nkatu, nmiss, score, max_combo, perfect, grade, mods, passed, mode, play_time
	if #parts < 16 then
		res:send("")
		return
	end

	-- Extract map MD5 and username
	local map_md5 = parts[1]
	local username = parts[2]

	-- Authenticate player
	local pw_md5 = fields.pass or ""
	local player = self:lookupPlayer(username, pw_md5)
	if not player then
		res:send("")
		return
	end

	-- Add decoded client hash to fields for checksum validation
	fields.client_hash = client_hash or ""

	-- Submit score
	local chart_response = self.server.score_submitter:submit(player, parts, replay_data, fields)

	if chart_response then
		res:send(chart_response)
	else
		res:send("error: no")
	end
end

--- POST /web/osu-submit-modular-selector.php
--- Score submission with session token authentication.
--- Authenticated via token header.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuSubmitModularSelector(req, res, ctx)
	local token = req.headers:get("token")
	if not token then
		res.status = 401
		res:send("")
		return
	end

	local player = self.server.players:get(token)
	if not player then
		res:send("") -- Client will retry when online
		return
	end

	-- Parse multipart form fields
	local multipart, err = http_util.get_multipart(req)
	if not multipart then
		res.status = 400
		res:send(err or "invalid multipart")
		return
	end

	local fields = {}
	local score_parts = {}

	multipart:receive_preamble()

	local headers, err = multipart:receive()
	while headers and err ~= "no parts" do
		local part_data = multipart.bsoc:receiveany(1024 * 1024)
		if part_data then
			local disp = headers:get("Content-Disposition") or ""
			local field_name = disp:match('name="([^"]+)"')
			if field_name then
				if field_name == "score" then
					table.insert(score_parts, part_data)
				else
					fields[field_name] = part_data
				end
			end
		end

		headers, err = multipart:receive()
	end

	-- Extract score data and replay
	if #score_parts < 2 then
		res:send("")
		return
	end

	local score_data_b64 = score_parts[1]
	local replay_data = score_parts[2]

	-- Decrypt score data
	local iv = fields.iv or ""
	local osuver = fields.osuver or ""
	local client_hash_b64 = fields.s or ""

	local score_crypto = ScoreCrypto:new()
	local score_data, client_hash = score_crypto:decryptScore(score_data_b64, client_hash_b64, iv, osuver)
	if not score_data then
		res:send("")
		return
	end

	-- Parse score data (colon-delimited)
	local parts = {}
	for part in score_data:gmatch("[^:]+") do
		parts[#parts + 1] = part
	end

	-- Minimum fields check
	if #parts < 16 then
		res:send("")
		return
	end

	-- Add decoded client hash to fields for checksum validation
	fields.client_hash = client_hash or ""

	-- Submit score
	local chart_response = self.server.score_submitter:submit(player, parts, replay_data, fields)

	if chart_response then
		res:send(chart_response)
	else
		res:send("error: no")
	end
end

-------------------------------------------------------------------
-- Leaderboards
-------------------------------------------------------------------

--- GET /web/osu-osz2-getscores.php
--- Returns leaderboard data for a beatmap.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuGetscores(req, res, ctx)
	local query = ctx.query

	-- Authenticate player
	local username = socket_url.unescape(query.us or query.u or "")
	local password_md5 = query.ha or query.h or ""
	if not username or not password_md5 then
		res:send("")
		return
	end

	local player = self:lookupPlayer(username, password_md5)
	if not player then
		res:send("")
		return
	end

	local map_md5 = query.c
	local map_filename = socket_url.unescape(query.f or "")
	local map_set_id = tonumber(query.i) or -1
	local mode = tonumber(query.m) or 0
	local mods = tonumber(query.mods) or 0
	local leaderboard_type = tonumber(query.v) or 0

	-- Handle relax/autopilot mode shifting
	if mods ~= 0 then
		if bit.band(mods, Mods.RELAX) ~= 0 then
			if mode ~= 3 then -- rx!mania doesn't exist
				mode = mode + 4
			else
				mods = bit.band(mods, bit.bnot(Mods.RELAX))
			end
		elseif bit.band(mods, Mods.AUTOPILOT) ~= 0 then
			if mode ~= 1 and mode ~= 2 and mode ~= 3 then
				mode = mode + 8
			else
				mods = bit.band(mods, bit.bnot(Mods.AUTOPILOT))
			end
		end
	end

	-- Look up beatmap: DB → local .osu file → API
	local bmap = nil
	if self.server.beatmap_repo then
		bmap = self.server.beatmap_repo:findBeatmap(map_md5)
	end

	-- If not in DB, try loading from local storage or API
	if not bmap and self.server.beatmap_loader then
		bmap = self.server.beatmap_loader:load(map_md5)
		if bmap and self.server.beatmap_repo then
			self.server.beatmap_repo:addBeatmap(bmap)
		end
	end

	if not bmap then
		res:send("-1|false")
		return
	end

	-- Check ranked status
	if bmap.status < RankedStatus.Ranked then
		res:send(tonumber(bmap.status) .. "|false")
		return
	end

	-- Fetch scores
	local scoring_metric = mode >= 4 and "pp" or "score"
	local scores = {}
	if self.server.score_repo then
		scores = self.server.score_repo:findScores(map_md5, mode)
	end

	-- Build response
	local response_lines = {
		string.format("%d|false|%d|%d|%d|0|",
			bmap.status, bmap.id, bmap.set_id, #scores),
		string.format("0\n%s\n0", bmap.full_name or ""),
		"", -- personal best (empty)
	}

	-- Add score entries
	for i, score in ipairs(scores) do
		if i > 50 then break end

		-- Resolve username
		local name = "unknown"
		if score.userid and self.server.user_repo then
			local user = self.server.user_repo:findUser(score.userid)
			if user then
				name = user.name or "unknown"
			end
		end

		table.insert(response_lines, string.format(
			"%d|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|1",
			score.id or 0,
			name,
			math.floor(score.score or 0),
			score.max_combo or 0,
			score.n50 or 0,
			score.n100 or 0,
			score.n300 or 0,
			score.nmiss or 0,
			score.ngeki or 0,
			score.nkatu or 0,
			score.perfect and 1 or 0,
			score.mods or 0,
			score.userid or 0,
			i,
			score.play_time or 0,
			1 -- has_replay
		))
	end

	res:send(table.concat(response_lines, "\n"))
end

-------------------------------------------------------------------
-- Replays
-------------------------------------------------------------------

--- GET /web/osu-getreplay.php
--- Serve replay file for a score.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuGetReplay(req, res, ctx)
	local query = ctx.query
	local score_id = tonumber(query.c)
	if not score_id then
		res.status = 404
		res:send("")
		return
	end

	if self.server.replay_repo then
		local replay_data = self.server.replay_repo:getReplay(score_id)
		if replay_data then
			res.headers:set("Content-Type", "application/octet-stream")
			res:send(replay_data)
			return
		end
	end

	res.status = 404
	res:send("")
end

-------------------------------------------------------------------
-- Friends
-------------------------------------------------------------------

--- POST /web/osu-getfriends.php
--- Return newline-delimited friend user IDs.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuGetFriends(req, res, ctx)
	local body, err = req:receive("*a")
	if not body then
		res:send(err or "")
		return
	end

	local params = http_util.decode_query_string(body)
	local username = socket_url.unescape(params.u or "")
	local password_md5 = params.h or ""

	local player = self:lookupPlayer(username, password_md5)
	if not player then
		res:send("")
		return
	end

	local friends = {}
	if self.server.friends_repo then
		friends = self.server.friends_repo:getFriends(player.id)
	end

	res:send(table.concat(friends, "\n"))
end

-------------------------------------------------------------------
-- Beatmap Info
-------------------------------------------------------------------

--- POST /web/osu-getbeatmapinfo.php
--- Beatmap info lookup by filename or ID.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuGetBeatmapInfo(req, res, ctx)
	local body, err = req:receive("*a")
	if not body then
		res:send(err or "")
		return
	end

	local params = http_util.decode_query_string(body)

	-- Parse filenames (Filenames[] format)
	---@type string[]
	local filenames = {}
	for k, v in pairs(params) do
		if k:match("^Filenames%[") then
			table.insert(filenames, v)
		end
	end

	local response_lines = {}
	for _, filename in ipairs(filenames) do
		local md5 = filename:match("^(%x+)%.")
		local bmap = nil
		if md5 and self.server.beatmap_repo then
			bmap = self.server.beatmap_repo:findBeatmap(md5)
		end

		-- If not in DB, try loading from local storage or API
		if not bmap and md5 and self.server.beatmap_loader then
			bmap = self.server.beatmap_loader:load(md5)
			if bmap and self.server.beatmap_repo then
				self.server.beatmap_repo:addBeatmap(bmap)
			end
		end

		if bmap then
			table.insert(response_lines, string.format(
				"%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|",
				bmap.set_id or 0,
				bmap.id or 0,
				bmap.artist or "",
				bmap.title or "",
				bmap.version or "",
				bmap.creator or "",
				bmap.status or "0",
				bmap.bpm or "0",
				bmap.drain or "0",
				bmap.circle_difficulty or "0",
				bmap.overall_difficulty or "0",
				bmap.approval_date or "0",
				bmap.playcount or "0",
				bmap.passcount or "0",
				bmap.total_length or "0"
			))
		else
			table.insert(response_lines, "")
		end
	end

	res:send(table.concat(response_lines, "\n"))
end

-------------------------------------------------------------------
-- Beatmap Search
-------------------------------------------------------------------

--- GET /web/osu-search.php
--- Beatmap search (proxies to osu! API mirror).
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuSearch(req, res, ctx)
	-- Search query is in ctx.query.s
	-- Returns newline-delimited lines of: set_id|difficulty_rating|playcount|passcount|status|bpm|title|artist|version|creator|length|md5
	local query_str = ctx.query.s or ""
	if #query_str == 0 then
		res:send("")
		return
	end

	-- TODO: implement beatmap search (proxy to osu! API or local DB)
	res:send("")
end

--- GET /web/osu-search-set.php
--- Beatmap set detail lookup.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuSearchSet(req, res, ctx)
	local set_id = tonumber(ctx.query.s) or tonumber(ctx.query.c)
	if not set_id then
		res:send("")
		return
	end

	-- TODO: implement beatmap set lookup
	res:send("")
end

-------------------------------------------------------------------
-- Favourites
-------------------------------------------------------------------

--- GET /web/osu-getfavourites.php
--- Return favourited beatmap set IDs.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuGetFavourites(req, res, ctx)
	local query = ctx.query
	local username = socket_url.unescape(query.u or "")
	local password_md5 = query.h or ""

	local player = self:lookupPlayer(username, password_md5)
	if not player then
		res:send("")
		return
	end

	local favourites = {}
	if self.server.favourites_repo then
		favourites = self.server.favourites_repo:getFavourites(player.id)
	end

	res:send(table.concat(favourites, "\n"))
end

--- GET /web/osu-addfavourite.php
--- Add beatmap set to favourites.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuAddFavourite(req, res, ctx)
	local query = ctx.query
	local username = socket_url.unescape(query.u or "")
	local password_md5 = query.h or ""
	local set_id = tonumber(query.b)

	local player = self:lookupPlayer(username, password_md5)
	if not player then
		res:send("Added favourite!")
		return
	end

	if set_id and self.server.favourites_repo then
		self.server.favourites_repo:addFavourite(player.id, set_id)
	end

	res:send("Added favourite!")
end

-------------------------------------------------------------------
-- Anti-Cheat (Last.fm)
-------------------------------------------------------------------

--- GET /web/lastfm.php
--- Anti-cheat endpoint. Client sends hidden flags.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:lastFm(req, res, ctx)
	local query = ctx.query
	local action = query.action
	local beatmap_id = query.b

	if not beatmap_id or beatmap_id:sub(1, 1) ~= "a" then
		res:send("-3")
		return
	end

	-- Parse anti-cheat flags
	local flags_str = beatmap_id:sub(2)
	local flags = tonumber(flags_str) or 0

	-- Check for hq!osu flags
	if bit.band(flags, 1) ~= 0 or bit.band(flags, 2) ~= 0 then
		-- HQ assembly or HQ file detected
		-- TODO: restrict player
		res:send("-3")
		return
	end

	res:send("")
end

-------------------------------------------------------------------
-- Screenshots
-------------------------------------------------------------------

--- POST /web/osu-screenshot.php
--- Screenshot upload.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuScreenshot(req, res, ctx)
	local multipart, err = http_util.get_multipart(req)
	if not multipart then
		res.status = 400
		res:send(err or "invalid multipart")
		return
	end

	-- Read preamble
	multipart:receive_preamble()

	-- Read part headers
	local headers, err = multipart:receive()
	if not headers then
		res.status = 400
		res:send(err or "invalid part")
		return
	end

	-- Read the image data
	local image_data = multipart.bsoc:receiveany(1024 * 1024) -- max 1MB
	if not image_data then
		res:send("")
		return
	end

	-- Validate image (check magic bytes)
	local magic = image_data:sub(1, 3):byte(1, 3)
	local valid = false
	if magic == 137 then valid = true -- PNG
	elseif magic == 255 then valid = true -- JPEG
	end

	if not valid then
		res:send("")
		return
	end

	-- TODO: save to disk with unique filename
	res:send("")
end

-------------------------------------------------------------------
-- Ratings
-------------------------------------------------------------------

--- GET /web/osu-rate.php
--- Beatmap rating submission and retrieval.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuRate(req, res, ctx)
	local query = ctx.query
	local action = query.action
	local beatmap_id = tonumber(query.b)

	if action == "rate" then
		-- Submit rating
		local username = socket_url.unescape(query.u or "")
		local password_md5 = query.h or ""
		local rating = tonumber(query.rating)

		local player = self:lookupPlayer(username, password_md5)
		if player and beatmap_id and rating then
			-- TODO: save rating to database
		end
		res:send("")
	elseif action == "get" then
		-- Get rating
		-- TODO: return average rating from database
		res:send("0")
	else
		res:send("ok")
	end
end

-------------------------------------------------------------------
-- Comments
-------------------------------------------------------------------

--- POST /web/osu-comment.php
--- Beatmap/replay comment get/post.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuComment(req, res, ctx)
	local body, err = req:receive("*a")
	if not body then
		res:send(err or "")
		return
	end

	local params = http_util.decode_query_string(body)
	local action = params.action

	if action == "add" then
		-- Add comment: type (beatmap/replay), id, text
		local username = socket_url.unescape(params.u or "")
		local password_md5 = params.h or ""
		local text = params.text

		local player = self:lookupPlayer(username, password_md5)
		if player and text then
			-- TODO: save comment to database
		end
		res:send("")
	elseif action == "get" then
		-- Get comments
		-- TODO: return comments from database
		res:send("")
	else
		res:send("")
	end
end

-------------------------------------------------------------------
-- Mail
-------------------------------------------------------------------

--- GET /web/osu-markasread.php
--- Mark mail conversation as read.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuMarkAsRead(req, res, ctx)
	local query = ctx.query
	local username = socket_url.unescape(query.u or "")
	local password_md5 = query.h or ""
	local conversation_id = tonumber(query.cid)

	local player = self:lookupPlayer(username, password_md5)
	if player and conversation_id then
		-- TODO: mark conversation as read in database
	end

	res:send("")
end

-------------------------------------------------------------------
-- Seasonal
-------------------------------------------------------------------

--- GET /web/osu-getseasonal.php
--- Return seasonal background configuration.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:osuGetSeasonal(req, res, ctx)
	local backgrounds = self.server.config.seasonal_backgrounds or {}
	util_send_json(res, backgrounds)
end

-------------------------------------------------------------------
-- Connection Checks
-------------------------------------------------------------------

--- GET /web/bancho_connect.php
--- Client connection check (called before login).
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:banchoConnect(req, res, ctx)
	res:send("")
end

--- GET /web/check-updates.php
--- Client update check.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function OsuWebResource:checkUpdates(req, res, ctx)
	res:send("")
end

return OsuWebResource
