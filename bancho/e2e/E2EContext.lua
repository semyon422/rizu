--- E2E test context.
---
--- Manages shared FakeSharedDict and a Sea server database for in-memory E2E tests.
--- Each request creates a fresh BanchoServer instance backed by the shared dicts
--- to simulate the multi-worker OpenResty model.

local SharedMemory = require("web.nginx.SharedMemory")
local BanchoAdapter = require("bancho.adapter")
local BanchoServer = require("bancho.server.BanchoServer")
local BanchoConfig = require("bancho.config.BanchoConfig")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local SeaRepos = require("sea.app.Repos")
local Domain = require("sea.app.Domain")
local FakeFilesystem = require("fs.FakeFilesystem")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ComputeContext = require("sea.compute.ComputeContext")
local ReplayComputer = require("sea.compute.ReplayComputer")
local ReplayBase = require("sea.replays.ReplayBase")
local digest = require("digest")
local bcrypt = require("bcrypt")

local class = require("class")

local sample_osu_template = [[
osu file format v14

[General]
Mode: %d
AudioFilename: audio.mp3
PreviewTime: 0

[Metadata]
Title:%s
Artist:%s
Creator:%s
Version:%s
BeatmapID:%d
BeatmapSetID:%d

[Difficulty]
CircleSize:4
OverallDifficulty:%s

[TimingPoints]
0,500,4,2,0,70,1,0

[HitObjects]
64,192,0,1,0,0:0:0:0:
192,192,1000,1,0,0:0:0:0:
320,192,2000,1,0,0:0:0:0:
448,192,3000,1,0,0:0:0:0:
]]

--- E2E test context.
---@class bancho.e2e.E2EContext
---@operator call: bancho.e2e.E2EContext
---@field shared_memory web.SharedMemory
---@field fs fs.FakeFilesystem
---@field db sea.ServerSqliteDatabase
---@field repos sea.Repos
---@field domain sea.Domain
---@field bancho_repos bancho.adapter.Repos
local E2EContext = class()

---@param overrides? table
---@return bancho.server.BanchoServer
function E2EContext:createServer(overrides)
	local server = BanchoServer(BanchoConfig(overrides), self.shared_memory)
	BanchoAdapter.setupSeaRepos(
		server,
		self.repos.users_repo,
		self.repos.leaderboards_repo,
		self.repos.charts_repo,
		self.repos.osu_repo,
		self.domain.osu_beatmaps,
		self.domain.charts_storage,
		self.domain.chartplay_submission,
		self.domain.replays_storage
	)
	return server
end

function E2EContext:new()
	self.shared_memory = SharedMemory()
	self.fs = FakeFilesystem()
	self.db = ServerSqliteDatabase(LjsqliteDatabase())
	self.db.path = ":memory:"
	self.db:remove()
	self.db:open()
	self.repos = SeaRepos(self.db.models, self.shared_memory)
	self.domain = Domain(self.repos, {
		osu_api = {client_id = "x", client_secret = "y", redirect_uri = "z"},
	}, self.fs, ReplayComputer(), "test")
	self.bancho_repos = BanchoAdapter.createSeaRepos(
		self.repos.users_repo,
		self.repos.leaderboards_repo,
		self.repos.charts_repo,
		self.repos.osu_repo,
		self.domain.osu_beatmaps,
		self.domain.charts_storage,
		self.domain.chartplay_submission,
		self.domain.replays_storage
	)
	return self
end

---@return bancho.http.BanchoProtocolResource
function E2EContext:createResource()
	local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
	return BanchoProtocolResource(self:createServer())
end

---@return bancho.http.AccountResource
function E2EContext:createAccountResource()
	local AccountResource = require("bancho.http.AccountResource")
	return AccountResource(self:createServer({allow_registration = true}))
end

---@param method string
---@param path string
---@param headers? {[string]: string}
---@param body? string
---@return web.IRequest
---@return web.IResponse
---@return bancho.e2e.ExtendedStringSocket
function E2EContext:createHttpRequest(method, path, headers, body)
	local ExtendedStringSocket = require("bancho.e2e.ExtendedStringSocket")
	local Request = require("web.http.Request")
	local Response = require("web.http.Response")

	body = body or ""
	headers = headers or {}

	local req_soc = ExtendedStringSocket()
	local res_soc = req_soc:split()

	local request_lines = {
		string.format("%s %s HTTP/1.0", method, path),
		"Host: osu.example.com",
		"Content-Length: " .. tostring(#body),
	}
	for name, value in pairs(headers) do
		request_lines[#request_lines + 1] = name .. ": " .. value
	end
	request_lines[#request_lines + 1] = ""
	request_lines[#request_lines + 1] = body

	res_soc:send(table.concat(request_lines, "\r\n"))

	local req = Request(req_soc, "r")
	local res = Response(res_soc, "w")
	req:receive_headers()
	return req, res, req_soc
end

---@param method string
---@param path string
---@param fields table
---@return web.IRequest
---@return web.IResponse
---@return bancho.e2e.ExtendedStringSocket
function E2EContext:createMultipartRequest(method, path, fields)
	local boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
	local body = ""
	for name, value in pairs(fields) do
		body = body .. string.format("\r\n--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s", boundary, name, value)
	end
	body = body .. string.format("\r\n--%s--\r\n", boundary)

	return self:createHttpRequest(method, path, {
		["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
	}, body)
end

---@param read_socket bancho.e2e.ExtendedStringSocket
---@return string
function E2EContext:readHttpResponse(read_socket)
	local raw = read_socket.soc.remainder or ""
	local header_end = raw:find("\r\n\r\n")
	if header_end then
		return raw:sub(header_end + 4)
	end
	return raw
end

---@param username string
---@param password_md5 string
---@param priv integer
---@return integer
function E2EContext:createUser(username, password_md5, priv)
	local user = assert(self.bancho_repos.user_repo:createUser(
		username,
		username .. "@test.com",
		bcrypt.digest(password_md5, 4),
		"US"
	))
	return user.id
end

---@param fields? table
---@return table
function E2EContext:createBeatmap(fields)
	fields = fields or {}
	local beatmap_id = fields.id or 12345
	local set_id = fields.set_id or 54321
	local title = fields.title or "Title"
	local artist = fields.artist or "Artist"
	local creator = fields.creator or "Mapper"
	local version = fields.version or "Insane"
	local mode = fields.mode or 3
	local od = fields.od or 8
	local content = fields.content or sample_osu_template:format(mode, title, artist, creator, version, beatmap_id, set_id, od)
	local hash = fields.md5 or digest.hash("md5", content, true)

	self.domain.charts_storage:set(hash, content)
	assert(self.repos.osu_repo:createBeatmap({
		id = beatmap_id,
		beatmapset_id = set_id,
		hash = hash,
		status = fields.osu_status or "ranked",
		updated_at = fields.updated_at or 100,
	}))

	local compute_ctx = ComputeContext()
	local chart_chartmeta = assert(compute_ctx:fromFileData(beatmap_id .. ".osu", content, 1))
	local chartmeta = chart_chartmeta.chartmeta
	chartmeta.hash = hash
	chartmeta.osu_beatmap_id = beatmap_id
	chartmeta.osu_beatmapset_id = set_id
	if fields.level ~= nil then
		chartmeta.level = fields.level
	end
	if fields.title ~= nil then
		chartmeta.title = fields.title
	end
	if fields.artist ~= nil then
		chartmeta.artist = fields.artist
	end
	if fields.version ~= nil then
		chartmeta.name = fields.version
	end
	if fields.creator ~= nil then
		chartmeta.creator = fields.creator
	end
	assert(self.repos.charts_repo:createUpdateChartmeta(chartmeta, fields.updated_at or 100))
	assert(self.repos.charts_repo:createUpdateChartdiff(compute_ctx:computeBase(ReplayBase()), fields.updated_at or 100))

	return assert(self.bancho_repos.beatmap_repo:findBeatmap(hash))
end

function E2EContext:close()
	self.db:close()
end

return E2EContext
