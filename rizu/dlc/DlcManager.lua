local class = require("class")
local ThreadRemote = require("threadremote.ThreadRemote")
local DlcTask = require("rizu.dlc.DlcTask")
local Observable = require("Observable")

---@class rizu.dlc.DlcManager
---@operator call: rizu.dlc.DlcManager
---@field network rizu.NetworkService?
local DlcManager = class()

---@param library rizu.library.Library
---@param network rizu.NetworkService?
function DlcManager:new(library, network)
	self.library = library
	self.network = network
	self.tasks = {} ---@type {[string|number]: rizu.dlc.DlcTask}
	self.is_sync = false
	self.onTaskUpdated = Observable()
	self.onDlcCompletedSignal = Observable()
	self.workingDirectory = love.filesystem.getSource()
end

---@param is_sync boolean
function DlcManager:setSync(is_sync)
	self.is_sync = is_sync
end

function DlcManager:load()
	if self.is_sync then
		self.worker = self:createAndLoadWorker(self.workingDirectory)
	else
		self.tr = ThreadRemote("rizu.dlc.DlcManager", self)
		self.tr.task_handler.timeout = 3600 -- 1 hour
		self.worker = self.tr:start(self.createAndLoadWorker, self.workingDirectory)
	end
end

---@param workingDirectory string
function DlcManager:createAndLoadWorker(workingDirectory)
	require("preload")
	local DlcWorker = require("rizu.dlc.DlcWorker")
	local request
	local download
	local network = self.network
	if self.is_sync and network then
		request = function(url)
			return network:request(url)
		end
		download = function(url, options)
			return network:download(url, options)
		end
	end
	local worker = DlcWorker(self, workingDirectory, request, download)
	return worker
end

function DlcManager:update()
	if self.tr then
		self.tr:update()
	end
end

function DlcManager:unload()
	if self.tr then
		self.tr:stopDetached()
		self.tr = nil
	end
end

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
		-- Use no-return call (- prefix) because progress is reported via updateTask
		(-self.worker):download(id, _type, provider_name, metadata)
	end)()
end

--- Internal method called by worker via ThreadRemote
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

--- Internal method called by worker via ThreadRemote
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
