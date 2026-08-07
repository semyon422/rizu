local IKeyValueStorage = require("sea.chart.storage.IKeyValueStorage")
local path_util = require("path_util")

---@class sea.FolderStorage: sea.IKeyValueStorage
---@operator call: sea.FolderStorage
local FolderStorage = IKeyValueStorage + {}

---@param fs fs.IFilesystem
---@param prefix string
function FolderStorage:new(fs, prefix)
	self.fs = fs
	self.prefix = prefix
end

---@param key string
---@return string?
---@return string?
function FolderStorage:get(key)
	local path = path_util.join(self.prefix, key)
	return self.fs:read(path)
end

---@param key string
---@param value string
---@return true?
---@return string?
function FolderStorage:set(key, value)
	local path = path_util.join(self.prefix, key)
	local dir = path:match("^(.*)/[^/]+$")
	if dir and not self.fs:getInfo(dir) then
		local ok = self.fs:createDirectory(dir)
		if not ok then
			return nil, "create directory failed"
		end
	end

	local temporary_path = path .. (".tmp.%d.%d"):format(os.time(), math.random(0, 0x7fffffff))
	local ok, err = self.fs:write(temporary_path, value)
	if not ok then
		return nil, err
	end

	ok, err = self.fs:move(temporary_path, path)
	if not ok then
		self.fs:remove(temporary_path)
		return nil, err
	end
	return true
end

return FolderStorage
