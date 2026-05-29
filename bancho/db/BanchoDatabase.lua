--- SQLite database wrapper for the bancho module.
---
--- Wraps LjsqliteDatabase with ORM, models, and migration support.
--- Follows the same pattern as `sea.storage.server.ServerSqliteDatabase`.

local class = require("class")
local TableOrm = require("rdb.TableOrm")
local Models = require("rdb.Models")
local SqliteMigrator = require("rdb.db.SqliteMigrator")
local autoload = require("autoload")
local io_util = require("io_util")

local user_version = 1

---@class bancho.BanchoDatabase
---@operator call: bancho.BanchoDatabase
---@field db rdb.LjsqliteDatabase
---@field orm rdb.TableOrm
---@field models rdb.Models
local BanchoDatabase = class()

BanchoDatabase.path = "bancho.db"

--- Create a new BanchoDatabase instance.
---@param db rdb.LjsqliteDatabase
function BanchoDatabase:new(db)
	self.db = db
	self.orm = TableOrm(db)
	self.models = Models(autoload("bancho.db.models", true), self.orm)
	self.migrator = SqliteMigrator(db)

	self.migrations = setmetatable({}, {
		__index = function(t, k)
			local path = ("bancho/db/migrations/%s.sql"):format(k)
			local content = io_util.read_file(path)
			t[k] = content
			return content
		end,
	})
end

--- Remove the database file.
function BanchoDatabase:remove()
	os.remove(self.path)
end

--- Open the database connection, initialize schema if needed.
function BanchoDatabase:open()
	local db = self.db
	db:open(self.path)
	db:exec("PRAGMA journal_mode = WAL")
	db:exec("PRAGMA synchronous = NORMAL")
	db:exec("PRAGMA busy_timeout = 10000")
	db:exec("PRAGMA foreign_keys = ON")

	local ver = db:user_version()

	if ver == 0 then
		db:exec(io_util.read_file("bancho/db/schema.sql"))
		db:user_version(user_version)
	else
		self:migrate()
	end
end

--- Close the database connection.
function BanchoDatabase:close()
	self.db:close()
end

--- Run pending migrations.
function BanchoDatabase:migrate()
	self.migrator:migrate(user_version, self.migrations)
end

return BanchoDatabase
