--- Geolocation stub for testing.
---
--- Returns a fixed country for all IP addresses.

local class = require("class")

---@class bancho.stub.GeoLocator
local GeoLocator = class()

function GeoLocator:new(country)
	self._country = country or "US"
	return self
end

--- Lookup country for an IP address.
---@param ip string
---@return {acronym: string, numeric: integer}
function GeoLocator:lookup(ip)
	return {
		acronym = self._country,
		numeric = 840, -- US default
	}
end

return GeoLocator
