local class = require("class")
local http_util = require("web.http.util")
local json = require("json")

---@class rizu.dlc.providers.BeatconnectProvider: rizu.dlc.IDlcProvider
---@operator call: rizu.dlc.providers.BeatconnectProvider
---@field request fun(url: string): {status: integer, body: string}?, string?
local BeatconnectProvider = class()

---@param config {request: fun(url: string): {status: integer, body: string}?, string?}
function BeatconnectProvider:new(config)
	self.apiUrl = "https://beatconnect.io/api/search/"
	self.downloadUrlPattern = "https://beatconnect.io/b/%s"
	self.request = assert(config.request, "request is required")
end

---@param query string
---@param filters table?
---@return table[]? results, string? error
function BeatconnectProvider:search(query, filters)
	filters = filters or {}
	local page = filters.page or 1
	local status = filters.status or "ranked"

	-- Beatconnect API: q=query, m=3 (mania), s=status, p=page
	local queryParams = {
		q = query,
		m = 3,
		s = status,
		p = page - 1, -- Assuming 0-based pagination
	}

	local url = self.apiUrl .. "?" .. http_util.encode_query_string(queryParams)
	print("[BeatconnectProvider] Requesting URL:", url)
	local res, err = self.request(url)

	if not res then
		return nil, err or "HTTP request failed"
	end

	local ok, data = pcall(json.decode, res.body)
	if not ok then
		return nil, "Failed to decode JSON response"
	end

	-- Beatconnect returns an array of mapsets or an object with 'beatmaps' (which are mapsets in their terms)
	local mapsets = data
	if type(data) == "table" and data.beatmaps then
		mapsets = data.beatmaps
	end

	local results = {}
	for _, set in ipairs(mapsets) do
		-- Normalize to common result format
		table.insert(results, {
			id = set.id,
			title = set.title,
			artist = set.artist,
			creator = set.creator,
			status = set.status,
			difficulties = set.beatmaps, -- Beatconnect calls difficulties 'beatmaps' inside the set
			thumbnail_url = ("https://assets.ppy.sh/beatmaps/%s/covers/card.jpg"):format(set.id),
		})
	end

	return results
end

---@param id string|number
---@return string? url, string? error
function BeatconnectProvider:getDownloadUrl(id)
	return self.downloadUrlPattern:format(id)
end

return BeatconnectProvider
