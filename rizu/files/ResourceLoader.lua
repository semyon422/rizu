local class = require("class")
local table_util = require("table_util")
local OJM = require("chart.format.o2jam.OJM")
local S3P = require("chart.format.iidx.S3P")
local S3PAudio = require("chart.format.iidx.S3PAudio")
local TwoDx = require("chart.format.iidx.TwoDx")
local ChartfileReader = require("rizu.library.ChartfileReader")

---@class rizu.ResourceLoader
---@operator call: rizu.ResourceLoader
local ResourceLoader = class()

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
function ResourceLoader:load(resources)
	local fs = self.fs
	local resource_finder = self.resource_finder

	self.file_paths = {}
	local file_paths = self.file_paths

	---@type string[]
	local new_paths = {}

	for _type, paths in resources:iter() do
		local name = paths[1]
		for _, path in ipairs(paths) do
			local found_path = resource_finder:findFile(path, _type)
			if found_path then
				file_paths[name] = found_path
				table.insert(new_paths, found_path)

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

---@param name string
---@return string?
function ResourceLoader:getResource(name)
	return self.file_contents[self.file_paths[name]]
end

return ResourceLoader
