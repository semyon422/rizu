local class = require("class")
local http_util = require("web.http.util")
local json = require("json")
local socket_url = require("socket.url")

---@class rizu.dlc.providers.EtternaPackProvider: rizu.dlc.IDlcProvider
---@operator call: rizu.dlc.providers.EtternaPackProvider
---@field request fun(url: string): {status: integer, body: string}?, string?
local EtternaPackProvider = class()

---@param config {request: fun(url: string): {status: integer, body: string}?, string?}?
function EtternaPackProvider:new(config)
	config = config or {}
	self.apiUrl = "https://api.etternaonline.com/api/packs"
	self.downloadUrlPattern = "https://downloads.etternaonline.com/ranked/%s.zip"
	self.request = config.request or http_util.request
end

---@param query string
---@param filters table?
---@return table[]? results, string? error
function EtternaPackProvider:search(query, filters)
	filters = filters or {}
	local page = filters.page or 1
	local limit = filters.limit or 36
	local sort = filters.sort or "name"
	
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
	return self.downloadUrlPattern:format(socket_url.escape(id))
end

return EtternaPackProvider
