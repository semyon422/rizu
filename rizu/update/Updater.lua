local class = require("class")
local json = require("json")

---@class rizu.Updater
---@operator call: rizu.Updater
local Updater = class()

---@param updater_io rizu.UpdaterIO
function Updater:new(updater_io)
	self.updater_io = updater_io
end

Updater.status = ""

---@class rizu.UpdateFile
---@field path string
---@field hash integer?
---@field hash_old integer?
---@field url string?

---@param server sphere.FilesConfig
---@param client sphere.FilesConfig
---@return rizu.UpdateFile[]
function Updater:mergeLists(server, client)
	---@type {[string]: rizu.UpdateFile}
	local map = {}
	for _, file in ipairs(server) do
		local path = file.path
		map[path] = map[path] or {}
		map[path].hash = file.hash
		map[path].url = file.url
		map[path].path = path
	end
	for _, file in ipairs(client) do
		local path = file.path
		map[path] = map[path] or {}
		map[path].hash_old = file.hash
		map[path].path = path
	end

	---@type rizu.UpdateFile[]
	local list = {}
	for _, file in pairs(map) do
		table.insert(list, file)
	end
	table.sort(list, function(a, b)
		return a.path < b.path
	end)

	return list
end

---@param server_filelist sphere.FilesConfig
---@param client_filelist sphere.FilesConfig
---@return rizu.UpdateFile[] download
---@return rizu.UpdateFile[] remove
---@return rizu.UpdateFile[] found
function Updater:getActionLists(server_filelist, client_filelist)
	local filelist = self:mergeLists(server_filelist, client_filelist)

	---@type rizu.UpdateFile[]
	local download = {}
	---@type rizu.UpdateFile[]
	local remove = {}
	---@type rizu.UpdateFile[]
	local found = {}

	for _, file in ipairs(filelist) do
		if not file.hash then
			table.insert(remove, file)
		elseif not file.hash_old or file.hash ~= file.hash_old then
			local _hash = self.updater_io:crc32Async(file.path)
			if _hash ~= file.hash then
				table.insert(download, file)
			else
				table.insert(found, file)
			end
		end
	end

	return download, remove, found
end

---@param status string
function Updater:setStatus(status)
	self.status = status
	print(status)
end

---@param update_url string
---@param client_filelist sphere.FilesConfig
---@return boolean?
---@return sphere.FilesConfig?
function Updater:updateFilesAsync(update_url, client_filelist)
	self:setStatus("Checking for updates...")

	local response = self.updater_io:downloadAsync(update_url)
	if not response then
		self:setStatus("Can't download file list")
		return
	end

	local ok, server_filelist = pcall(json.decode, response)
	if not ok then
		self:setStatus("Can't decode json")
		return
	end

	---@cast server_filelist sphere.FilesConfig
	local download, remove, found = self:getActionLists(server_filelist, client_filelist)

	for _, file in ipairs(found) do
		self:setStatus("found: " .. file.path)
	end

	for _, file in ipairs(download) do
		self:setStatus("download: " .. file.path)
		local ok, err = self.updater_io:downloadAsync(file.url, file.path)
		if not ok then
			self:setStatus(err)
			return
		end
	end
	for _, file in ipairs(remove) do
		self:setStatus("remove: " .. file.path)
		self.updater_io:removeAsync(file.path)
	end

	local count = #download + #remove
	self:setStatus("files updated: " .. count)

	return count > 0, server_filelist
end

return Updater
