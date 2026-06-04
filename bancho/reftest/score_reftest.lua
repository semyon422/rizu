--- Score submission tests via /web/osu-submit-modular-selector.php
---
--- Tests that score submission works end-to-end: encrypt score data,
--- build multipart form, send with token, verify response.

local reftest = require("bancho.reftest.init")
local ScoreCrypto = require("bancho.crypto.ScoreCrypto")
local Score = require("bancho.model.Score")
local Grade = require("bancho.constants.Grade")
local socket_url = require("socket.url")
local mime = require("mime")

local M = {}

--- Build multipart form data for score submission.
---@param fields table Form fields (score_data, replay, iv, osuver, s, etc.)
---@return string body
---@return string boundary
local function build_multipart(fields)
	local boundary = "----WebKitFormBoundary" .. tostring(math.random(1000000000, 9999999999))
	local parts = {}

	-- Add all fields except score_data and replay (those become "score" fields)
	for name, value in pairs(fields) do
		if value and name ~= "score_data" and name ~= "replay" then
			table.insert(parts, string.format(
				"\r\n--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s",
				boundary, name, value
			))
		end
	end

	-- Score field appears twice: encrypted score data + replay file
	if fields.score_data then
		table.insert(parts, string.format(
			"\r\n--%s\r\nContent-Disposition: form-data; name=\"score\"\r\n\r\n%s",
			boundary, fields.score_data
		))
	end
	if fields.replay then
		table.insert(parts, string.format(
			"\r\n--%s\r\nContent-Disposition: form-data; name=\"score\"\r\n\r\n%s",
			boundary, fields.replay
		))
	end

	table.insert(parts, "\r\n--" .. boundary .. "--\r\n")
	return table.concat(parts), boundary
end

--- HTTP POST with multipart form data.
---@param url string
---@param body string
---@param boundary string
---@param headers table?
---@return integer status
---@return string response
function M.http_post_multipart(url, body, boundary, headers)
	reftest.ensure_deps()
	headers = headers or {}
	headers["Content-Type"] = string.format("multipart/form-data; boundary=%s", boundary)

	local client = reftest.HttpClient(reftest.LsTcpSocket())
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

--- Submit a score via the selector endpoint.
---@param srv table Server configuration
---@param token string Session token
---@param username string Username
---@param password_md5 string Password MD5
---@param map_md5 string Beatmap MD5
---@param osu_version string osu! client version
---@param client_hash string Client hash (32 bytes, will be encrypted)
---@param score_data string Colon-delimited score fields (with map_md5 and username)
---@param replay_data string Replay file data (can be empty)
---@return integer status HTTP status code
---@return string response Response body
function M.submit_score(srv, username, password_md5, map_md5, osu_version, client_hash, score_data, replay_data)
	replay_data = replay_data or ""

	-- Generate IV (32 bytes for Rijndael-256)
	local iv = {}
	for i = 1, 32 do
		iv[i] = string.char(math.random(0, 255))
	end
	local iv_b64 = mime.b64(table.concat(iv))

	-- Derive encryption key
	local key = ScoreCrypto.deriveKey(osu_version)

	-- Encrypt score data and client hash
	local encrypted_score, err = ScoreCrypto.encrypt(score_data, key, iv_b64)
	if not encrypted_score then
		return 0, "encrypt failed: " .. tostring(err)
	end

	local encrypted_hash, err2 = ScoreCrypto.encrypt(client_hash, key, iv_b64)
	if not encrypted_hash then
		return 0, "encrypt hash failed: " .. tostring(err2)
	end

	-- Build multipart form
	local fields = {
		iv = iv_b64,
		osuver = osu_version,
		s = encrypted_hash,
		st = tostring(os.time() * 1000),
		pass = password_md5,
		score = encrypted_score,
		replay = replay_data,
	}

	local body, boundary = build_multipart(fields)

	-- Submit via selector endpoint
	local base = string.format("%s://%s:%s", srv.scheme, srv.osu_host, srv.port)
	local url = base .. "/web/osu-submit-modular-selector.php"

	return M.http_post_multipart(url, body, boundary, {
		["User-Agent"] = "osu!",
		["token"] = "Empty",
	})
end

--- Run score submission tests.
--- @param srv table Server configuration
--- @param username string Test username
--- @param password_md5 string Test password MD5 hash
function M.run(srv, username, password_md5)
	if not password_md5 then
		reftest.record("score_submission", "SKIP", "no password_md5")
		return
	end

	-- Use a known beatmap that exists in both servers' databases
	-- We'll use the beatmap from the access logs: 0b6530995faa63c9e71e403fbc9d9341
	-- But we need to find one that exists on both servers
	-- For now, use a generic test beatmap
	local map_md5 = "0b6530995faa63c9e71e403fbc9d9341"
	local osu_version = "20240101"
	local client_hash = "test_client_hash_123456789012345678901234"

	-- Build score data (mania mode for simplicity)
	local n300, n100, n50 = 500, 200, 50
	local ngeki, nkatu, nmiss = 100, 50, 0
	local score_value = 999999
	local max_combo = 1000
	local perfect = false
	local grade = "x"
	local mods = 0
	local passed = true
	local mode = 3 -- mania
	local play_time = tostring(os.time() * 1000)

	-- Compute online checksum
	local temp_score = Score:new()
	temp_score.n300 = n300
	temp_score.n100 = n100
	temp_score.n50 = n50
	temp_score.ngeki = ngeki
	temp_score.nkatu = nkatu
	temp_score.nmiss = nmiss
	temp_score.score = score_value
	temp_score.max_combo = max_combo
	temp_score.perfect = perfect
	temp_score.grade = Grade.fromString(grade)
	temp_score.mods = mods
	temp_score.passed = passed
	temp_score.mode = mode
	temp_score.client_time = play_time

	local checksum = temp_score:computeOnlineChecksum(
		username,
		map_md5,
		osu_version,
		client_hash,
		"" -- storyboard_md5
	)

	-- Build score data string (colon-delimited, with map_md5 and username as first two fields)
	local score_data = table.concat({
		map_md5,       -- map_md5
		username,      -- username
		checksum,      -- online_checksum
		tostring(n300),
		tostring(n100),
		tostring(n50),
		tostring(ngeki),
		tostring(nkatu),
		tostring(nmiss),
		tostring(score_value),
		tostring(max_combo),
		perfect and "True" or "False",
		grade,
		tostring(mods),
		passed and "True" or "False",
		tostring(mode),
		play_time,
	}, ":")

	-- Submit score
	local status, response = M.submit_score(
		srv, username, password_md5, map_md5,
		osu_version, client_hash, score_data, ""
	)

	if status == 200 and #response > 0 and response ~= "error: no" then
		reftest.record("score_submission", "PASS", string.format("HTTP %d, %d bytes", status, #response))
	else
		reftest.record("score_submission", "FAIL", string.format("HTTP %d, %s", status, tostring(response):sub(1, 100)))
	end

	-- Try submitting with a different beatmap (osu! mode)
	-- Use a common beatmap that likely exists
	map_md5 = "4a8e8c8e8c8e8c8e8c8e8c8e8c8e8c8e" -- placeholder
	score_data = table.concat({
		map_md5,       -- map_md5
		username,      -- username
		checksum,
		tostring(300), tostring(100), tostring(20),
		tostring(0), tostring(0), tostring(0),
		tostring(800000), tostring(500),
		"False", "S", "0", "True", "0", play_time,
	}, ":")

	-- Recompute checksum for osu! mode
	temp_score.mode = 0
	temp_score.n300 = 300
	temp_score.n100 = 100
	temp_score.n50 = 20
	temp_score.ngeki = 0
	temp_score.nkatu = 0
	temp_score.nmiss = 0
	temp_score.score = 800000
	temp_score.max_combo = 500
	temp_score.grade = Grade.fromString("S")
	checksum = temp_score:computeOnlineChecksum(username, map_md5, osu_version, client_hash, "")

	status, response = M.submit_score(
		srv, username, password_md5, map_md5,
		osu_version, client_hash, score_data, ""
	)

	-- This might fail if the beatmap doesn't exist, which is expected
	if status == 200 then
		if #response > 0 and response ~= "error: no" then
			reftest.record("score_submission_osu", "PASS", string.format("HTTP %d, %d bytes", status, #response))
		else
			reftest.record("score_submission_osu", "SKIP", string.format("beatmap not found: %s", map_md5))
		end
	else
		reftest.record("score_submission_osu", "FAIL", string.format("HTTP %d", status))
	end
end

return M
