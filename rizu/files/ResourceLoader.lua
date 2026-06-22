local class = require("class")
local thread = require("thread")
local table_util = require("table_util")
local OJM = require("chart.format.o2jam.OJM")
local S3P = require("chart.format.iidx.S3P")
local S3PAudio = require("chart.format.iidx.S3PAudio")
local TwoDx = require("chart.format.iidx.TwoDx")
local ChartfileReader = require("rizu.library.ChartfileReader")

---@class rizu.ResourceLoader
---@operator call: rizu.ResourceLoader
local ResourceLoader = class()

---@class rizu.ResourceEntry
---@field type chart.ResourceType
---@field paths string[]

---@class rizu.ResourceLoaderSnapshot
---@field finder {paths: string[], path_files: {[string]: {lookup: {[string]: string}, stems: {[string]: {[string]: string}}}}}
---@field file_paths {[string|integer]: string}
---@field file_contents {[string]: string}

---@param fs fs.IFilesystem
---@param resource_finder rizu.ResourceFinder
function ResourceLoader:new(fs, resource_finder)
	self.fs = fs
	self.resource_finder = resource_finder

	---@type {[string|integer]: string}
	self.file_paths = {}
	---@type {[string]: string}
	self.file_contents = {}

	---@type {[string]: true}
	self.file_pendings = {}

	---@type {[string]: string}
	self.resources = setmetatable({}, {__index = function(t, k)
		return self:getResource(k)
	end})
end

---@param resources chart.Resources
---@return rizu.ResourceEntry[]
function ResourceLoader.getResourceEntries(resources)
	---@type rizu.ResourceEntry[]
	local entries = {}
	for _type, paths in resources:iter() do
		table.insert(entries, {
			type = _type,
			paths = paths,
		})
	end
	return entries
end

---@param entries rizu.ResourceEntry[]
function ResourceLoader:loadEntries(entries)
	local fs = self.fs
	local resource_finder = self.resource_finder

	self.file_paths = {}
	local file_paths = self.file_paths

	---@type string[]
	local new_paths = {}

	for _, entry in ipairs(entries) do
		local _type = entry.type
		local paths = entry.paths
		local name = paths[1]
		for _, path in ipairs(paths) do
			local found_path = resource_finder:findFile(path, _type)
			if found_path then
				file_paths[name] = found_path

				if _type == "ojm" then
					local data = ChartfileReader.read(fs, found_path)
					if data then
						local ojm = OJM(data)
						for id, sample_data in pairs(ojm.samples) do
							local virtual_path = found_path .. ":" .. id
							file_paths[id] = virtual_path
							self.file_contents[virtual_path] = sample_data
							table.insert(new_paths, virtual_path)
						end
					end
				elseif _type == "s3p" then
					local data = ChartfileReader.read(fs, found_path)
					if data then
						local pack = S3P.parse(data)
						for id = 1, pack.count do
							local sample_data = S3PAudio.payload_by_id(pack, id)
							if sample_data then
								local virtual_path = found_path .. ":" .. id
								file_paths[tostring(id)] = virtual_path
								self.file_contents[virtual_path] = sample_data
								table.insert(new_paths, virtual_path)
							end
						end
					end
				elseif _type == "2dx" then
					local data = ChartfileReader.read(fs, found_path)
					if data then
						local archive = TwoDx.parse(data)
						for id = 1, archive.count do
							local sample_data = TwoDx.payload(archive, id)
							local sample_name = tostring(id)
							if sample_data and not file_paths[sample_name] then
								local virtual_path = found_path .. ":" .. id
								file_paths[sample_name] = virtual_path
								self.file_contents[virtual_path] = sample_data
								table.insert(new_paths, virtual_path)
							end
						end
					end
				else
					table.insert(new_paths, found_path)
				end
				if _type ~= "2dx" then
					break
				end
			end
		end
	end

	---@type string[]
	local old_paths = {}
	for path in pairs(self.file_contents) do
		table.insert(old_paths, path)
	end

	local new, old = table_util.array_update2(new_paths, old_paths)

	for _, path in ipairs(old) do
		self.file_contents[path] = nil
	end

	self.file_pendings = {}
	local file_pendings = self.file_pendings
	for _, path in ipairs(new) do
		file_pendings[path] = true
	end

	local path = next(file_pendings)
	while path do
		file_pendings[path] = nil
		if not self.file_contents[path] then
			self.file_contents[path] = ChartfileReader.read(fs, path)
		end
		path = next(file_pendings)
	end
end

---@param resources chart.Resources
function ResourceLoader:load(resources)
	self:loadEntries(ResourceLoader.getResourceEntries(resources))
end

---@return rizu.ResourceLoaderSnapshot
function ResourceLoader:getSnapshot()
	return {
		finder = self.resource_finder:getSnapshot(),
		file_paths = self.file_paths,
		file_contents = self.file_contents,
	}
end

---@param snapshot rizu.ResourceLoaderSnapshot
function ResourceLoader:applySnapshot(snapshot)
	self.resource_finder:applySnapshot(snapshot.finder)
	self.file_paths = snapshot.file_paths
	self.file_contents = snapshot.file_contents
	self.file_pendings = {}
end

local function loadAsyncWorker(entries, paths)
	local LoveFilesystem = require("fs.LoveFilesystem")
	local ResourceFinder = require("rizu.files.ResourceFinder")
	local WorkerResourceLoader = require("rizu.files.ResourceLoader")

	local fs = LoveFilesystem()
	local resource_finder = ResourceFinder(fs)
	for _, path in ipairs(paths) do
		resource_finder:addPath(path)
	end

	local resource_loader = WorkerResourceLoader(fs, resource_finder)
	resource_loader:loadEntries(entries)
	return resource_loader:getSnapshot()
end

local async_load = thread.async(loadAsyncWorker)

---@param entries rizu.ResourceEntry[]
---@param paths string[]
---@return thread.Future
function ResourceLoader.startEntriesAsync(entries, paths)
	local future_load = thread.future(loadAsyncWorker)
	return future_load(entries, paths)
end

---@param resources chart.Resources
---@param paths string[]
---@return thread.Future
function ResourceLoader:startLoadAsync(resources, paths)
	return ResourceLoader.startEntriesAsync(ResourceLoader.getResourceEntries(resources), paths)
end

---@param future thread.Future
---@return rizu.ResourceLoaderSnapshot
function ResourceLoader:waitLoadAsync(future)
	return thread.wait(future)
end

---@param resources chart.Resources
---@param paths string[]
---@return rizu.ResourceLoaderSnapshot
function ResourceLoader:loadAsync(resources, paths)
	return async_load(ResourceLoader.getResourceEntries(resources), paths)
end

---@param name string
---@return string?
function ResourceLoader:getResource(name)
	return self.file_contents[self.file_paths[name]]
end

return ResourceLoader
