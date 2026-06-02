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
