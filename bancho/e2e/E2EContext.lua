--- E2E test context.
---
--- Manages shared FakeSharedDict and SQLite database for in-memory E2E tests.
--- Each request creates a fresh BanchoServer instance backed by the shared dicts
--- to simulate the multi-worker OpenResty model.
---
--- Uses `web.SharedMemory` which automatically falls back to `FakeSharedDict`
--- when `ngx.shared` is nil (test environment). A single SharedMemory instance
--- is shared across all BanchoServer instances so they see the same dicts.

local SharedMemory = require("web.nginx.SharedMemory")
local BanchoServer = require("bancho.server.BanchoServer")
local Repos = require("bancho.db.repos")
local bcrypt = require("bcrypt")

local class = require("class")

--- E2E test context.
--- Creates shared fake shared-memory and a temporary SQLite database.
--- Each call to :createResource() produces a fresh BanchoServer + resource pair.
---@class bancho.e2e.E2EContext
---@operator call: bancho.e2e.E2EContext
---@field shared_memory web.SharedMemory Shared memory (uses FakeSharedDict in tests)
---@field db bancho.BanchoDatabase Database instance
local E2EContext = class()

function E2EContext:new()
	-- Single SharedMemory instance shared across all BanchoServer instances.
	-- In tests, ngx.shared is nil so SharedMemory falls back to FakeSharedDict.
	-- Dicts are cached per-instance so all servers see the same data.
	self.shared_memory = SharedMemory()

	-- Use in-memory database
	local BanchoDatabase = require("bancho.db.BanchoDatabase")
	local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
	self.db = BanchoDatabase(LjsqliteDatabase())
	self.db.path = ":memory:"
	self.db:open()
	return self
end

--- Create a fresh BanchoProtocolResource backed by a new BanchoServer.
--- Simulates a new worker handling a request.
---@return bancho.http.BanchoProtocolResource
function E2EContext:createResource()
	-- Create server with shared memory and in-memory DB override
	local server = BanchoServer(self.shared_memory, {
		db_path = ":memory:",
	})

	-- Wire up repos from the shared database
	local repos = Repos(self.db.models)
	server:setRepos(
		repos.user_repo,
		repos.score_repo,
		repos.beatmap_repo,
		repos.friends_repo,
		repos.favourites_repo,
		repos.stats_repo,
		repos.replay_repo
	)

	local BanchoProtocolResource = require("bancho.http.BanchoProtocolResource")
	return BanchoProtocolResource(server)
end

--- Create a fresh AccountResource backed by a new BanchoServer.
--- Simulates a new worker handling a registration request.
---@return bancho.http.AccountResource
function E2EContext:createAccountResource()
	local server = BanchoServer(self.shared_memory, {
		db_path = ":memory:",
		allow_registration = true,
	})

	-- Wire up repos from the shared database
	local repos = Repos(self.db.models)
	server:setRepos(
		repos.user_repo,
		repos.score_repo,
		repos.beatmap_repo,
		repos.friends_repo,
		repos.favourites_repo,
		repos.stats_repo,
		repos.replay_repo
	)

	local AccountResource = require("bancho.http.AccountResource")
	return AccountResource(server)
end

--- Create an HTTP request/response pair for testing with multipart body.
--- Uses ExtendedStringSocket to simulate HTTP without real networking.
---@param method string HTTP method (GET, POST, etc.)
---@param path string Request path
---@param fields table Form fields
---@return web.IRequest request
---@return web.IResponse response
---@return bancho.e2e.ExtendedStringSocket read_socket socket to read response from
function E2EContext:createMultipartRequest(method, path, fields)
	local ExtendedStringSocket = require("bancho.e2e.ExtendedStringSocket")
	local Request = require("web.http.Request")
	local Response = require("web.http.Response")

	-- Create socket pair
	local req_soc = ExtendedStringSocket()
	local res_soc = req_soc:split()

	-- Build multipart body
	-- Format must match what MultipartString expects: \r\n--boundary\r\nheaders\r\n\r\nvalue
	local boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
	local body = ""
	for name, value in pairs(fields) do
		body = body .. string.format("\r\n--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s", boundary, name, value)
	end
	body = body .. string.format("\r\n--%s--\r\n", boundary)

	-- Build request string
	local request_lines = {
		string.format("%s %s HTTP/1.0", method, path),
		"Host: osu.example.com",
		"Content-Type: multipart/form-data; boundary=" .. boundary,
		"Content-Length: " .. tostring(#body),
		"", -- blank line separates headers from body
		body,
	}
	local request_str = table.concat(request_lines, "\r\n")

	-- Send request data to res_soc so it appears in req_soc (for Request to read)
	res_soc:send(request_str)

	-- Create real Request/Response objects
	local req = Request(req_soc, "r")
	local res = Response(res_soc, "w")

	req:receive_headers()

	-- Response writes to res_soc, data appears in req_soc for us to read
	return req, res, req_soc
end

--- Read the HTTP response body from a socket.
---@param read_socket bancho.e2e.ExtendedStringSocket
---@return string body
function E2EContext:readHttpResponse(read_socket)
	local raw = read_socket.soc.remainder or ""
	local header_end = raw:find("\r\n\r\n")
	if header_end then
		return raw:sub(header_end + 4)
	end
	return raw
end

--- Create a user in the database for testing.
---@param username string
---@param password_md5 string
---@param priv integer
---@return integer user_id
function E2EContext:createUser(username, password_md5, priv)
	local repos = Repos(self.db.models)

	-- Store bcrypt hash of the MD5 password
	local pw_bcrypt = bcrypt.digest(password_md5, 4)

	local user = repos.user_repo:createUser(username, username .. "@test.com", pw_bcrypt, "US")
	repos.user_repo:partialUpdate(user.id, {priv = priv})
	return user.id
end

--- Clean up temp database.
function E2EContext:close()
	self.db:close()
end

return E2EContext
