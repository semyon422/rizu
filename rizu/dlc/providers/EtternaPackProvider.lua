local class = require("class")
local http_util = require("web.http.util")
local json = require("json")
local socket_url = require("socket.url") --[[@as {escape: fun(value: string|number): string}]]

---@class rizu.dlc.providers.EtternaPack
---@field name string
---@field author string?
---@field size number?
---@field date string?
---@field average_diff number?
---@field total_songs integer?

---@class rizu.dlc.providers.EtternaResponse
---@field data rizu.dlc.providers.EtternaPack[]?
---@field [integer] rizu.dlc.providers.EtternaPack

---@class rizu.dlc.providers.EtternaFilters
---@field page integer?
---@field limit integer?
---@field sort string?
---@field key_count integer?
---@field tags string?

---@class rizu.dlc.providers.EtternaPackProvider: rizu.dlc.IDlcProvider
---@operator call: rizu.dlc.providers.EtternaPackProvider
---@field request fun(url: string): {status: integer, body: string}?, string?
local EtternaPackProvider = class()

---@param config {request: fun(url: string): {status: integer, body: string}?, string?}
function EtternaPackProvider:new(config)
	self.apiUrl = "https://api.etternaonline.com/api/packs"
	self.downloadUrlPattern = "https://downloads.etternaonline.com/ranked/%s.zip"
	self.request = assert(config.request, "request is required")
end

---@param query string
---@param filters rizu.dlc.providers.EtternaFilters?
---@return table[]? results, string? error
function EtternaPackProvider:search(query, filters)
	filters = filters or {}
	local page = filters.page or 1
	local limit = filters.limit or 36
	local sort = filters.sort or "name"
	
	---@type {[string]: string|number}
	local queryParams = {
		page = page,
		limit = limit,
		sort = sort,
		["filter[search]"] = query
	}
	
	-- Additional filters from spec
	if filters.key_count then
		queryParams["filter[key_count]"] = filters.key_count
	end
	if filters.tags then
		queryParams["filter[tags]"] = filters.tags
	end

	local url = self.apiUrl .. "?" .. http_util.encode_query_string(queryParams)
	print("[EtternaPackProvider] Requesting URL:", url)
	local res, err = self.request(url)

	if not res then
		return nil, err or "HTTP request failed"
	end

	local ok, data = pcall(json.decode, res.body)
	if not ok then
		return nil, "Failed to decode JSON response"
	end

	---@cast data rizu.dlc.providers.EtternaResponse
	local results = {}
	-- The API might return an object with a 'data' field or just an array.
	-- Assuming 'data' based on typical modern APIs or the structure of the search endpoint.
	local packs = data.data or data
	
	for _, pack in ipairs(packs) do
		table.insert(results, {
			id = pack.name, -- Using name as ID for downloads
			name = pack.name,
			author = pack.author,
			size = pack.size,
			date = pack.date,
			average_diff = pack.average_diff,
			total_songs = pack.total_songs,
		})
	end

	return results
end

---@param id string|number
---@return string? url, string? error
function EtternaPackProvider:getDownloadUrl(id)
	-- Etterna packs use their name in the download URL
	local escape = socket_url.escape --[[@as fun(value: string|number): string]]
	return self.downloadUrlPattern:format(escape(id))
end

return EtternaPackProvider
