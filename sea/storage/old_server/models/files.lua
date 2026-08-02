local Formats = require("sea.storage.old_server.Formats")
local Storages = require("sea.storage.old_server.Storages")
local Filehash = require("sea.storage.old_server.Filehash")

---@class sea.old.File
---@field id integer
---@field hash string
---@field name string
---@field format sea.old.Formats
---@field storage sea.old.Storages
---@field uploaded boolean
---@field size integer
---@field loaded boolean
---@field created_at integer
---@field path string

---@type rdb.ModelOptions
local files = {}

files.types = {
	uploaded = "boolean",
	loaded = "loaded",
	hash = Filehash,
	format = Formats,
	storage = Storages,
}

files.relations = {
	notecharts = {has_many = "notecharts", key = "file_id"},
	scores = {has_many = "scores", key = "file_id"},
}

---@param file sea.old.File
function files.from_db(file)
	file.path = "server-state/storages/" .. file.storage .. "/" .. file.hash
end

return files
