local class = require("class")

---Files of the remote catalog kept on disk, so a file is downloaded once.
---@class rizu.library.RemoteAssetCache
---@operator call: rizu.library.RemoteAssetCache
---@field network rizu.NetworkService
---@field fs fs.IFilesystem
---@field directory string
local RemoteAssetCache = class()

---@param network rizu.NetworkService
---@param fs fs.IFilesystem
---@param directory string?
function RemoteAssetCache:new(network, fs, directory)
	self.network = assert(network, "network is required")
	self.fs = assert(fs, "filesystem is required")
	self.directory = directory or "userdata/online/assets"
end

---Where the file of an url is kept: the url's path under the directory.
---@param url string
---@return string?
function RemoteAssetCache:getPath(url)
	local path = url:gsub("^%a[%w+.-]*://[^/]*/", ""):gsub("[?#].*$", "")
	if path == "" or path:find("..", 1, true) or path:find("^/") or path:find("\\", 1, true) then
		return nil
	end
	return self.directory .. "/" .. path
end

---@param url string
---@return string?
---@return string?
function RemoteAssetCache:download(url)
	local res, err = self.network:download(url, {chunk_size = 64 * 1024})
	if not res then
		return nil, err or "download failed"
	end
	if res.status >= 400 then
		return nil, "HTTP " .. res.status
	end
	return res.body
end

---@param path string
---@param data string
---@return boolean?
---@return string?
function RemoteAssetCache:write(path, data)
	local directory = path:match("^(.*)/[^/]+$")
	if directory and not self.fs:createDirectory(directory) then
		return nil, "could not create " .. directory
	end
	local ok, err = self.fs:write(path, data)
	if not ok then
		return nil, err or ("could not write " .. path)
	end
	return true
end

---The file of the url, downloaded first if it is not cached. Yields.
---@param url string
---@return string?
---@return string?
function RemoteAssetCache:get(url)
	local path = self:getPath(url)
	if not path then
		return nil, "unsupported url " .. url
	end
	local data = self.fs:read(path)
	if data then
		return data
	end
	local body, err = self:download(url)
	if not body then
		return nil, err
	end
	-- A failed write only costs the next download.
	self:write(path, body)
	return body
end

return RemoteAssetCache
