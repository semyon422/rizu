local class = require("class")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local SqliteMigrator = require("rdb.db.SqliteMigrator")
local TableOrm = require("rdb.TableOrm")
local Models = require("rdb.Models")
local sql_util = require("rdb.sql_util")
local autoload = require("autoload")

---@class rizu.library.Database
---@operator call: rizu.library.Database
local Database = class()

local user_version = 8

---@param fs fs.IFilesystem
---@param migrations table?
function Database:new(fs, migrations)
	self.fs = fs
	self.migrations = migrations or {}

	local db = LjsqliteDatabase()
	self.db = db

	self.orm = TableOrm(db)
	self.models = Models(autoload("rizu.library.models"), self.orm)

	self.migrator = SqliteMigrator(db)
end

---@param path string?
function Database:load(path)
	local db = self.db

	db:open(path or "userdata/data.db")
	db:exec("PRAGMA journal_mode = WAL")
	db:exec("PRAGMA synchronous = NORMAL")
	db:exec("PRAGMA busy_timeout = 10000")
	db:exec("PRAGMA foreign_keys = ON")

	local ver = db:user_version()

	if ver == 0 then
		db:exec(assert(self.fs:read("rizu/library/sql/database.sql")))
		db:exec(assert(self.fs:read("sea/storage/shared/db.sql")))
		db:user_version(user_version)
		ver = user_version
	elseif ver >= 4 then
		self:migrate()
	else
		error("outdated database")
	end
end

function Database:unload()
	self.db:close()
end

function Database:migrate()
	local count = self.migrator:migrate(user_version, self.migrations)
	if count > 0 then
		print("migrations applied: " .. count)
	end
end

return Database
