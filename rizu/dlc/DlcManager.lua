local class = require("class")
local DlcWorker = require("rizu.dlc.DlcWorker")
local DlcTask = require("rizu.dlc.DlcTask")
local Observable = require("Observable")

---@class rizu.dlc.DlcManager
---@operator call: rizu.dlc.DlcManager
---@field network rizu.NetworkService
local DlcManager = class()

---@param library rizu.library.Library
---@param network rizu.NetworkService
function DlcManager:new(library, network)
	self.library = library
	self.network = assert(network, "network is required")
	self.tasks = {} ---@type {[string|number]: rizu.dlc.DlcTask}
	self.onTaskUpdated = Observable()
	self.onDlcCompletedSignal = Observable()
	self.workingDirectory = love.filesystem.getSource()
end

function DlcManager:load()
	self.worker = self:createAndLoadWorker(self.workingDirectory)
end

---@param workingDirectory string
function DlcManager:createAndLoadWorker(workingDirectory)
	local network = self.network
	local worker = DlcWorker(
		self,
		workingDirectory,
		function(url)
			return network:request(url)
		end,
		function(url, options)
			return network:download(url, options)
		end
	)
	return worker
end

function DlcManager:update() end

function DlcManager:unload() end

---@param query string
---@param filters table?
---@param provider_name string?
---@return table[]? results, string? error
function DlcManager:search(query, filters, provider_name)
	return self.worker:search(query, filters, provider_name)
end

---@param url string
---@return string? data, string? error
function DlcManager:fetchThumbnail(url)
	return self.worker:fetchThumbnail(url)
end

---@param id string|number
---@param _type rizu.dlc.DlcType
---@param provider_name string?
---@param metadata table?
function DlcManager:download(id, _type, provider_name, metadata)
	provider_name = provider_name or "mino"
	if self.tasks[id] then return end

	local task = DlcTask(id, provider_name, _type, metadata)
	self.tasks[id] = task
	self.onTaskUpdated:send({task = task})

	coroutine.wrap(function()
		self.worker:download(id, _type, provider_name, metadata)
	end)()
end

---@param id string|number
---@param updates table
function DlcManager:updateTask(id, updates)
	local task = self.tasks[id]
	if not task then return end

	for k, v in pairs(updates) do
		task[k] = v
	end
	self.onTaskUpdated:send({task = task})
end

---@param id string|number
---@param _type rizu.dlc.DlcType
---@param metadata table?
function DlcManager:onDlcCompleted(id, _type, metadata)
	self.onDlcCompletedSignal:send({id = id, type = _type, metadata = metadata})
	
	if _type == "pack" then
		-- Trigger library import for packs
		self.library:computeLocation("packs", 1)
	elseif _type == "set" then
		-- Trigger library import for set (e.g., .osz)
		self.library:computeLocation("downloads", 1)
	elseif _type == "file" then
		-- For single files, we might have a specific destination directory
		local path = "downloads"
		if metadata and metadata.dest_dir then
			-- Extract relative path from userdata/charts if possible
			-- For now, just scan the whole downloads if it starts with it
			if metadata.dest_dir:find("userdata/charts/downloads") then
				path = metadata.dest_dir:gsub("userdata/charts/", "")
			end
		end
		self.library:computeLocation(path, 1)
	end
end

return DlcManager
