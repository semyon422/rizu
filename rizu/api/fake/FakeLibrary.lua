local Events = require("rizu.api.Events")

---`rizu.api.Library` with two made-up folders that are never scanned.
---@class rizu.api.fake.FakeLibrary : rizu.api.Events
---@operator call: rizu.api.fake.FakeLibrary
local FakeLibrary = Events + {}

function FakeLibrary:new()
	Events.new(self)
	self.next_id = 3
	self.locations = {
		{id = 1, name = "Songs", path = "songs", is_relative = true, is_internal = true},
		{id = 2, name = "Etterna", path = "/home/player/Etterna/Songs", is_relative = false, is_internal = false},
	}
end

function FakeLibrary:getLocations() return self.locations end

function FakeLibrary:getLocationInfo(location)
	return {status = "mounted", chart_sets = 30, charts = 120, hashed_charts = 120}
end

function FakeLibrary:getLocationPath(location)
	return location.is_relative and "/game/" .. location.path or location.path
end

function FakeLibrary:addLocation(name, path)
	table.insert(self.locations, {id = self.next_id, name = name, path = path, is_relative = false, is_internal = false})
	self.next_id = self.next_id + 1
	self:emit("locations_changed")
	return true
end

function FakeLibrary:updateLocation(location, name, path)
	location.name, location.path = name, path
	self:emit("locations_changed")
	return true
end

function FakeLibrary:deleteLocation(location)
	if location.is_internal then return false end
	for i, other in ipairs(self.locations) do
		if other == location then table.remove(self.locations, i) end
	end
	self:emit("locations_changed")
	return true
end

function FakeLibrary:toggleCacheUpdate(location) end

function FakeLibrary:getCacheStatus() return {stage = "idle", current = 0, total = 0} end

return FakeLibrary
