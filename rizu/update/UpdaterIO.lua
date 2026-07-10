local class = require("class")
local thread = require("thread")

---@class rizu.UpdaterIO
---@operator call: rizu.UpdaterIO
local UpdaterIO = class()

local async_download = thread.async(function(url, path)
	local http_util = require("web.http.util")
	local socket_url = require("socket.url")

	url = socket_url.build(socket_url.parse(url))

	local ok, res = pcall(http_util.request, url)
	if not ok or not res then
		return
	end
	if res.status >= 400 then
		return
	end

	local body = res.body
	if not body or not path then
		return body
	end

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

function UpdaterIO:downloadAsync(url, path)
	return async_download(url, path)
end

function UpdaterIO:removeAsync(path)
	return async_remove(path)
end

function UpdaterIO:crc32Async(path)
	return async_crc32(path)
end

return UpdaterIO
