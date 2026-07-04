local class = require("class")
local table_util = require("table_util")
local path_util = require("path_util")
local sql_util = require("rdb.sql_util")

---@class rizu.library.FileCacheGenerator
---@operator call: rizu.library.FileCacheGenerator
local FileCacheGenerator = class()

---@class rizu.library.ChartfileSetDraft
---@field dir string?
---@field name string
---@field modified_at number
---@field is_file boolean
---@field location_id integer

---@param chartfilesRepo rizu.library.ChartfilesRepo
---@param finder rizu.library.Finder
---@param taskContext rizu.library.ITaskContext
function FileCacheGenerator:new(chartfilesRepo, finder, taskContext)
	self.chartfilesRepo = chartfilesRepo
	self.finder = finder
	self.taskContext = taskContext
end

---@param root_dir string?
---@param location_id integer
---@param location_prefix string?
function FileCacheGenerator:scan(root_dir, location_id, location_prefix)
	local iterator = self.finder:iter(location_prefix, root_dir)
	local chartfile_set, chartfile
	local discovered_count = 0
	local iterations = 0

	local typ, dir, name, modtime = iterator()
	while typ do
		iterations = iterations + 1
		if iterations % 1000 == 0 and self.taskContext:shouldStop() then break end

		local res
		if name and typ == "related_dir" then
			chartfile_set = self:processChartfileSet({
				dir = dir,
				name = assert(name),
				modified_at = modtime,
				is_file = false,
				location_id = location_id,
			})
		elseif chartfile_set and typ == "related" then
			---@cast name string
			---@cast modtime number
			chartfile = self:processChartfile(chartfile_set.id, name, modtime)
			discovered_count = discovered_count + 1
			self.taskContext:advance(1)
		elseif chartfile_set and typ == "related_all" then
			---@cast name string[]
			self.chartfilesRepo:deleteChartfiles({set_id = chartfile_set.id, name__notin = name})
			chartfile_set = nil
		elseif typ == "unrelated_dir" then
		elseif typ == "unrelated" then
			---@cast name string
			---@cast modtime number
			chartfile_set = self:processChartfileSet({
				dir = dir,
				name = name,
				modified_at = modtime,
				is_file = true,
				location_id = location_id,
			})
			chartfile = self:processChartfile(chartfile_set.id, name, modtime)
			discovered_count = discovered_count + 1
			self.taskContext:advance(1)
		elseif typ == "unrelated_all" then
			---@cast name string[]
			self.chartfilesRepo:deleteChartfiles({set_id = chartfile_set.id, name__notin = name})
			self.chartfilesRepo:deleteChartfileSets({
				dir = dir,
				dir__isnull = not dir,
				name__notin = name,
				location_id = location_id,
			})
		elseif typ == "directory_dir" then
		elseif typ == "directory" then
			---@cast name string
			---@cast modtime number
			res = self:shouldScan(dir, name, modtime, location_id)
		elseif typ == "directory_all" then
			---@cast name string[]
			local names_current = table_util.invert(name)
			local chartfile_sets = self.chartfilesRepo:selectChartfileSetsAtLocation(location_id, dir)
			local names_to_delete = {}
			for _, set in ipairs(chartfile_sets) do
				if not names_current[set.name] then
					table.insert(names_to_delete, set.name)
				end
			end
			for _, slice in ipairs(table_util.slices(names_to_delete, 1024)) do
				self.chartfilesRepo:deleteChartfileSets({
					dir = dir,
					dir__isnull = not dir,
					name__in = slice,
					location_id = location_id,
				})
			end
		elseif typ == "not_found" then
			self.chartfilesRepo:deleteChartfileSets({
				dir = dir,
				dir__isnull = not dir,
				name = name,
				location_id = location_id,
			})
		end
		typ, dir, name, modtime = iterator(res)
	end

	-- Clean up missing directory sets
	if not root_dir then
		local tdirs = self.chartfilesRepo:selectChartfileSetsDirs(location_id)
		for _, tdir in ipairs(tdirs) do
			iterations = iterations + 1
			if iterations % 1000 == 0 and self.taskContext:shouldStop() then break end
			if tdir.dir then
				local dir = path_util.join(location_prefix, tdir.dir)
				if not self.finder.fs:getInfo(dir) then
					self.chartfilesRepo:deleteChartfileSets({
						dir = tdir.dir,
						location_id = location_id,
					})
				end
			end
		end
	end
end

---@param dir string?
---@param name string
---@param modified_at number
---@param location_id integer
---@return boolean
function FileCacheGenerator:shouldScan(dir, name, modified_at, location_id)
	local chartfile_set = self.chartfilesRepo:selectChartfileSet(dir, name, location_id)
	if not chartfile_set then
		return true
	end
	if chartfile_set.modified_at ~= modified_at then
		return true
	end
	return false
end

---@param chartfile_set rizu.library.ChartfileSetDraft
---@return sea.ClientChartfileSet
function FileCacheGenerator:processChartfileSet(chartfile_set)
	local _chartfile_set = self.chartfilesRepo:selectChartfileSet(
		chartfile_set.dir,
		chartfile_set.name,
		chartfile_set.location_id
	)

	if _chartfile_set then
		if _chartfile_set.modified_at ~= chartfile_set.modified_at then
			_chartfile_set.modified_at = chartfile_set.modified_at
			self.chartfilesRepo:updateChartfileSet(_chartfile_set)
		end
		return _chartfile_set
	end

	_chartfile_set = self.chartfilesRepo:insertChartfileSet(chartfile_set)

	return _chartfile_set
end

---@param name string
---@param set_id integer
---@param modified_at number
---@return sea.ClientChartfile
function FileCacheGenerator:processChartfile(set_id, name, modified_at)
	local chartfile = self.chartfilesRepo:selectChartfile(set_id, name)

	if not chartfile then
		return self.chartfilesRepo:insertChartfile({
			name = name,
			modified_at = modified_at,
			set_id = set_id,
		})
	end

	if chartfile.modified_at ~= modified_at then
		chartfile.hash = sql_util.NULL
		chartfile.modified_at = modified_at
		self.chartfilesRepo:updateChartfile(chartfile)
	end

	return chartfile
end

return FileCacheGenerator
