local path_util = require("path_util")
local Events = require("rizu.api.Events")

--[[
Where the chart files are: the folders ("locations") the game scans, and the scan itself.

	local library = ui.api.library
	for _, location in ipairs(library:getLocations()) do
		local info = library:getLocationInfo(location)
		drawRow(location.name, library:getLocationPath(location), info.charts)
	end
	local ok, err = library:addLocation("Etterna", "/home/me/Etterna/Songs")
	library:on("cache_status_changed", function(status) ... end)

Adding, changing or deleting a location lists the charts again by itself.
Scanning a location is slow and goes on in the background: follow it with getCacheStatus().
]]

---@alias rizu.api.Library.Event
---| "locations_changed" # A location was added, changed or deleted. No arguments.
---| "cache_status_changed" # The scan moved on, started or ended. Arguments: status, a rizu.api.CacheStatus.

---A folder with charts. The game's own table: read it, do not change it.
---@class rizu.api.Location
---@field id integer
---@field name string
---@field path string Where the folder is, relative to the game's folder when `is_relative`. See getLocationPath().
---@field is_relative boolean
---@field is_internal boolean The game's own folder: it cannot be moved, changed or deleted.
---@field url string? Remote locations only: where the catalog's files are downloaded from.

---@class rizu.api.CacheStatus
---@field stage string "idle" when nothing is being scanned, otherwise what the scan is doing.
---@field current integer How many items are done in this stage.
---@field total integer 0 when the game does not know yet.
---@field items_per_second number?
---@field eta number? Seconds left in this stage.

---@class rizu.api.LocationInfo
---@field status string "unknown" before the game has looked at the folder.
---@field chart_sets integer
---@field charts integer
---@field hashed_charts integer Charts that are already in the library.

---@param status rizu.library.TaskStatus
---@return rizu.api.CacheStatus
local function toCacheStatus(status)
	return {
		stage = status.stage,
		current = status.current,
		total = status.total,
		items_per_second = status.itemsPerSecond,
		eta = status.eta,
	}
end

---@class rizu.api.Library : rizu.api.Events
---@operator call: rizu.api.Library
---@field on fun(self: rizu.api.Library, event: rizu.api.Library.Event, f: function): fun()
---@field private game sphere.GameController
local Library = Events + {}

---@param game sphere.GameController
function Library:new(game)
	Events.new(self)
	self.game = game
	game.library.onStatusChanged:add(function(status)
		self:emit("cache_status_changed", toCacheStatus(status))
	end)
end

---@param self rizu.api.Library
local function changed(self)
	local game = self.game ---@diagnostic disable-line: invisible
	game.library.locations:selectLocations()
	game.chartSelector:noDebounceRefresh()
	self:emit("locations_changed")
end

---Reads the locations again, so it is up to date when a screen is entered.
---@return rizu.api.Location[]
function Library:getLocations()
	local locations = self.game.library.locations
	locations:selectLocations()
	return locations.locations --[[@as rizu.api.Location[] ]]
end

---@param location rizu.api.Location
---@return rizu.api.LocationInfo
function Library:getLocationInfo(location)
	local locations = self.game.library.locations
	local info = locations.info[location.id] or {}
	return {
		status = locations.status[location.id] or "unknown",
		chart_sets = info.chartfile_sets or 0,
		charts = info.chartfiles or 0,
		hashed_charts = info.hashed_chartfiles or 0,
	}
end

---The full path of the folder, for showing.
---@param location rizu.api.Location
---@return string
function Library:getLocationPath(location)
	if location.is_relative then
		return path_util.join(self.game.library.locations.root, location.path)
	end
	return location.path
end

---@param name string
---@param path string
---@return boolean ok
---@return string? err
function Library:addLocation(name, path)
	local library = self.game.library
	local created ---@type rizu.library.Location?
	local ok, err = pcall(function()
		created = library.locationsRepo:insertLocation({
			name = name, path = path, is_relative = false, is_internal = false,
		})
		library.locations:updateLocationPath(created, path)
	end)
	if not ok then
		if created then
			library.locations:deleteLocation(created.id)
		end
		return false, tostring(err)
	end
	changed(self)
	return true
end

---Renames the location and points it at another folder. If that fails nothing is changed.
---@param location rizu.api.Location
---@param name string
---@param path string
---@return boolean ok
---@return string? err
function Library:updateLocation(location, name, path)
	local library = self.game.library
	local repo = library.locationsRepo
	local previous ---@type rizu.library.Location?
	local ok, err = pcall(function()
		local current = assert(repo:selectLocationById(location.id), "Location no longer exists")
		previous = {
			id = current.id,
			name = current.name,
			path = current.path,
			is_relative = current.is_relative,
			is_internal = current.is_internal,
		}
		library.locations:updateLocationPath(current, path)
		current.name = name
		repo:updateLocation(current)
	end)
	if not ok then
		if previous then
			pcall(function()
				repo:updateLocation(previous)
				library.locations:mountLocation(previous)
			end)
		end
		return false, tostring(err)
	end
	changed(self)
	return true
end

---Removes the location from the game. Its files stay where they are.
---@param location rizu.api.Location
---@return boolean deleted False for the game's own folder.
function Library:deleteLocation(location)
	if not self.game.library.locations:deleteLocation(location.id) then
		return false
	end
	changed(self)
	return true
end

-- Scanning

---Scans the location for charts and adds them to the library. While a scan is running, stops it instead.
---@param location rizu.api.Location
function Library:toggleCacheUpdate(location) self.game.selectionActions:updateCacheLocation(location.id) end

---@return rizu.api.CacheStatus
function Library:getCacheStatus() return toCacheStatus(self.game.library.status) end

return Library
