local class = require("class")
local Config = require("rizu.config.Config")

---@class rizu.config.ConfigManager
---@operator call: rizu.config.ConfigManager
---@field fs fs.IFilesystem
---@field configs {[string]: rizu.config.Config}
---@field paths {[string]: string}
local ConfigManager = class()

---@param filesystem fs.IFilesystem
function ConfigManager:new(filesystem)
	self.fs = filesystem
	self.configs = {}
	self.paths = {}
end

---@param id string
---@param schema table
---@param path string
---@return rizu.config.Config
function ConfigManager:register(id, schema, path)
	local config = Config(schema)
	self.configs[id] = config
	self.paths[id] = path
	return config
end

---@param id string
---@return rizu.config.Config?
function ConfigManager:get(id)
	return self.configs[id]
end

---@param filename string
---@param config rizu.config.Config
---@return boolean success
function ConfigManager:load(filename, config)
	if not self.fs:getInfo(filename) then
		return false
	end
	local content, err = self.fs:read(filename)
	if not content then
		return false
	end
	return config:deserialize(content)
end

---@param filename string
---@param config rizu.config.Config
---@return boolean success
function ConfigManager:save(filename, config)
	local serialized = config:serialize()
	local ok, err = self.fs:write(filename, serialized)
	return not not ok
end

---@param id string
---@return boolean success
function ConfigManager:loadById(id)
	local config = self.configs[id]
	local path = self.paths[id]
	if not config or not path then
		return false
	end
	return self:load(path, config)
end

---@param id string
---@return boolean success
function ConfigManager:saveById(id)
	local config = self.configs[id]
	local path = self.paths[id]
	if not config or not path then
		return false
	end
	return self:save(path, config)
end

function ConfigManager:loadAll()
	for id in pairs(self.configs) do
		self:loadById(id)
	end
end

function ConfigManager:saveAll()
	for id in pairs(self.configs) do
		self:saveById(id)
	end
end

return ConfigManager
