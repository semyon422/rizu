local class = require("class")
local io_util = require("io_util")
local TableOrm = require("rdb.TableOrm")
local Models = require("rdb.Models")
local SqliteMigrator = require("rdb.db.SqliteMigrator")
local autoload = require("autoload")
local io_util = require("io_util")

---@class sea.ServerSqliteDatabase
---@operator call: sea.ServerSqliteDatabase
local ServerSqliteDatabase = class()

ServerSqliteDatabase.path = "server-state/server.db"

local user_version = 9

---@param db rdb.SqliteDatabase
function ServerSqliteDatabase:new(db)
	self.db = db
	self.orm = TableOrm(db)
	self.models = Models(autoload("sea.storage.server.models", true), self.orm)
	self.migrator = SqliteMigrator(db)

	self.migrations = setmetatable({}, {__index = function(_, k)
		return io_util.read_file(("sea/storage/server/migrations/%s.sql"):format(k))
	end})
end

function ServerSqliteDatabase:remove()
	os.remove(self.path)
end

function ServerSqliteDatabase:open()
	local db = self.db
	db:open(self.path)
	db:exec("PRAGMA journal_mode = WAL")
	db:exec("PRAGMA synchronous = NORMAL")
	db:exec("PRAGMA busy_timeout = 10000")
	db:exec("PRAGMA foreign_keys = ON")

	local ver = db:user_version()

	if ver == 0 then
		db:exec(io_util.read_file("sea/storage/server/db.sql"))
		db:exec(io_util.read_file("sea/storage/shared/db.sql"))
		db:exec(dofile("sea/storage/server/db.lua"))
		db:user_version(user_version)
		ver = user_version
	else
		self:migrate()
	end
end

function ServerSqliteDatabase:close()
	self.db:close()
end

function ServerSqliteDatabase:migrate()
	self.migrator:migrate(user_version, self.migrations)
end

return ServerSqliteDatabase
