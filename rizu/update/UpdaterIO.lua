local class = require("class")
local thread = require("thread")

---@class rizu.UpdaterIO
---@operator call: rizu.UpdaterIO
---@field network rizu.NetworkService
---@field write_func fun(path: string, body: string): boolean?, string?
---@field remove_func fun(path: string): boolean?
---@field crc32_func fun(path: string): integer?
local UpdaterIO = class()

local async_write = thread.async(function(path, body)
	local directory = path:match("^(.+)/.-$")
	if directory and not love.filesystem.createDirectory(directory) then
		return false, ("Could not open directory %s (not a directory)"):format(directory)
	end

	local ok, err = love.filesystem.write(path, body)
	if ok then
		return ok, err
	end

	os.rename(path, path .. ".old")
	return love.filesystem.write(path, body)
end)

local async_remove = thread.async(function(path)
	local ok = love.filesystem.remove(path)
	if ok then
		return ok
	end
	return os.rename(path, path .. ".old")
end)

local async_crc32 = thread.async(function(path)
	local content = love.filesystem.read(path)
	if not content then
		return
	end
	return require("crc32").hash(content)
end)

---@param network rizu.NetworkService
---@param write_func (fun(path: string, body: string): boolean?, string?)?
---@param remove_func (fun(path: string): boolean?)?
---@param crc32_func (fun(path: string): integer?)?
function UpdaterIO:new(network, write_func, remove_func, crc32_func)
	self.network = assert(network, "network is required")
	self.write_func = write_func or async_write
	self.remove_func = remove_func or async_remove
	self.crc32_func = crc32_func or async_crc32
end

function UpdaterIO:downloadAsync(url, path)
	local res, err = self.network:download(url)
	if not res then
		return nil, err
	end
	if res.status >= 400 then
		return nil, "HTTP " .. res.status
	end

	local body = res.body
	if not body or not path then
		return body
	end

	return self.write_func(path, body)
end

function UpdaterIO:removeAsync(path)
	return self.remove_func(path)
end

function UpdaterIO:crc32Async(path)
	return self.crc32_func(path)
end

return UpdaterIO
