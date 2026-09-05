local class = require("class")
local path_util = require("path_util")

---@class rizu.library.Locations
---@operator call: rizu.library.Locations
local Locations = class()

---@param locationsRepo rizu.library.LocationsRepo
---@param chartfilesRepo rizu.library.ChartfilesRepo
---@param fs fs.IFilesystem
---@param root string OS dependent, absolute
---@param prefix string
function Locations:new(locationsRepo, chartfilesRepo, fs, root, prefix)
	self.locationsRepo = locationsRepo
	self.chartfilesRepo = chartfilesRepo
	self.fs = fs
	self.root = root
	self.prefix = prefix
	---@type {[integer]: boolean}
	self.mounted = {}
	---@type {[integer]: string}
	self.status = {}
	---@type {[integer]: table}
	self.info = {}
	---@type rizu.library.Location[]
	self.locations = {}
	---@type {[integer]: rizu.library.Location}
	self.locationsById = {}
end

function Locations:load()
	self:createDefaultLocation()
	self:selectLocations()
	for _, location in ipairs(self.locations) do
		self:mountLocation(location)
	end
end

function Locations:unload()
	for _, location in ipairs(self.locations) do
		self:unmountLocation(location)
	end
end

function Locations:selectLocations()
	self.locations = self.locationsRepo:selectLocations()
	self.locationsById = {}
	for _, loc in ipairs(self.locations) do
		self:updateLocationInfo(loc.id)
		self.locationsById[loc.id] = loc
	end
end

---@param id integer
function Locations:updateLocationInfo(id)
	self.info[id] = {
		chartfile_sets = self.chartfilesRepo:countChartfileSets({location_id = id}),
		chartfiles = self.chartfilesRepo:countChartfiles({location_id = id}),
		hashed_chartfiles = self.chartfilesRepo:countChartfiles({
			location_id = id,
			hash__isnotnull = true,
		}),
	}
end

---@param location rizu.library.Location
function Locations:unmountLocation(location)
	if not self.mounted[location.id] then
		return
	end
	self.fs:unmount(location.path)
	self.mounted[location.id] = nil
end

---@param location rizu.library.Location
function Locations:mountLocation(location)
	local path = location.path
	if location.is_relative then
		self.status[location.id] = "direct access"
		return
	end
	if self.mounted[location.id] then
		self.status[location.id] = "mounted"
		return
	end
	local mp = path_util.join(self.prefix, location.id)
	if self.fs:mount(path, mp, true) then
		self.mounted[location.id] = true
		self.status[location.id] = "mounted"
		return
	end
	self.status[location.id] = "errored"
end

---@param location rizu.library.Location
---@return string
function Locations:getPrefix(location)
	if location.is_relative then
		return location.path
	end
	return path_util.join(self.prefix, location.id)
end

---@param chart rizu.library.LocatedChartview
function Locations:enrichChartview(chart)
	if not chart or not chart.location_id or chart.location_path then
		return
	end
	local location = self.locationsById[chart.location_id]
	if not location then
		location = self.locationsRepo:selectLocationById(chart.location_id)
		if not location then
			return
		end
		self.locationsById[chart.location_id] = location
	end
	local prefix = self:getPrefix(location)
	chart.location_prefix = prefix
	chart.location_dir = path_util.join(prefix, chart.dir)
	chart.location_path = path_util.join(prefix, chart.path)
	chart.real_dir = path_util.join(location.path, chart.dir)
	chart.real_path = path_util.join(location.path, chart.path)
end

function Locations:createDefaultLocation()
	---@type rizu.library.LocationInsert
	local loc = {
		path = "userdata/charts",
		name = "game",
		is_relative = true,
		is_internal = true,
	}

	local locationsRepo = self.locationsRepo

	local location = locationsRepo:selectLocation(loc.path)
	if location then
		return
	end

	locationsRepo:insertLocation(loc)
end

---@param loc rizu.library.Location
---@param path string
function Locations:updateLocationPath(loc, path)
	if not loc or loc.is_internal then
		return
	end

	self:unmountLocation(loc)

	loc.path = path_util.fix_separators(path)
	loc.is_relative = false

	local a, b = loc.path:find(self.root, 1, true)
	local separator = loc.path:sub((b or 0) + 1, (b or 0) + 1)
	if a == 1 and separator == "/" then
		loc.path = loc.path:sub(b + 2)
		loc.is_relative = true
	end

	self.locationsRepo:updateLocation(loc)
	self:mountLocation(loc)
end

---@param location_id integer
function Locations:deleteCharts(location_id)
	self.chartfilesRepo:deleteChartfileSets({
		location_id = assert(location_id),
	})
end

---@param location_id integer
---@return boolean deleted
function Locations:deleteLocation(location_id)
	local location = self.locationsRepo:selectLocationById(location_id)
	if not location or location.is_internal then
		return false
	end
	self:unmountLocation(location)
	self.locationsRepo:deleteLocation(location_id)
	self.locationsById[location_id] = nil
	self.status[location_id] = nil
	self.info[location_id] = nil
	return true
end

return Locations
