#!/usr/bin/env luajit

require("pkg_config")

local sqlite = require("ljsqlite3")

local state_root = os.getenv("RIZU_SERVER_STATE_PATH") or "server-state"
local output_path = assert(arg[1], "usage: ./scripts/backup.lua <snapshot-path>")
local database_path = state_root .. "/server.db"

assert(output_path ~= database_path, "backup snapshot must differ from the live database")
os.remove(output_path)

local database = sqlite.open(database_path)
database:exec("PRAGMA busy_timeout = 10000")
database:exec("VACUUM INTO " .. string.format("%q", output_path))
database:close()

local snapshot = sqlite.open(output_path)
local integrity = snapshot:rowexec("PRAGMA integrity_check")
snapshot:close()
assert(integrity == "ok", "backup integrity check failed: " .. tostring(integrity))
