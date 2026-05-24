local class = require("class")
local table_util = require("table_util")
local OJM = require("chart.format.o2jam.OJM")
local path_util = require("path_util")

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
					local data = fs:read(found_path)
					if data then
						local ojm = OJM(data)
						for id, sample_data in pairs(ojm.samples) do
							local virtual_path = found_path .. ":" .. id
							file_paths[id] = virtual_path
							self.file_contents[virtual_path] = sample_data
							table.insert(new_paths, virtual_path)
						end
					end
				end
				break
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
			self.file_contents[path] = fs:read(path)
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
