local class = require("class")

---@class rizu.dlc.providers.OsuFileProvider: rizu.dlc.IDlcProvider
---@operator call: rizu.dlc.providers.OsuFileProvider
local OsuFileProvider = class()

function OsuFileProvider:new()
	self.downloadUrlPattern = "https://osu.ppy.sh/osu/%s"
end

---@param query string
---@param filters table?
---@return table[]? results, string? error
function OsuFileProvider:search(query, filters)
	-- Individual file provider doesn't support searching by itself.
	-- Searching for beatmaps usually returns sets, and then you get individual IDs.
	return {}, nil
end

---@param id string|number
---@return string? url, string? error
function OsuFileProvider:getDownloadUrl(id)
	return self.downloadUrlPattern:format(id)
end

return OsuFileProvider
