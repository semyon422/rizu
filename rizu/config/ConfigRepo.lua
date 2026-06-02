local class = require("class")

---@class rizu.config.ConfigRepo
---@operator call: rizu.config.ConfigRepo
---@field filepath string
---@field fs fs.IFilesystem
local ConfigRepo = class()

---@param filepath string
---@param filesystem fs.IFilesystem
function ConfigRepo:new(filepath, filesystem)
	self.filepath = filepath
	self.fs = filesystem
end

---@param config rizu.config.Config
---@return boolean success
function ConfigRepo:load(config)
	if not self.fs:getInfo(self.filepath) then
		return false
	end
	local content, err = self.fs:read(self.filepath)
	if not content then
		return false
	end
	return config:deserialize(content)
end

---@param config rizu.config.Config
---@return boolean success
function ConfigRepo:save(config)
	local serialized = config:serialize()
	local ok, err = self.fs:write(self.filepath, serialized)
	return not not ok
end

return ConfigRepo
