local class = require("class")
local http_util = require("web.http.util")
local json = require("json")

---@class rizu.dlc.MinoBeatmapset
---@field id integer
---@field title string
---@field artist string
---@field creator string
---@field source string?
---@field tags string?
---@field status string?
---@field beatmaps table[]?
---@field video boolean?
---@field storyboard boolean?

---@class rizu.dlc.MinoProvider: rizu.dlc.IDlcProvider
---@operator call: rizu.dlc.MinoProvider
---@field request fun(url: string): {status: integer, body: string}?, string?
local MinoProvider = class()

-- TODO: rate limits, bg and audio preview

MinoProvider.search_url = "https://catboy.best/api/v2/search"
MinoProvider.download_url = "https://catboy.best/d/"

---@enum (key) rizu.dlc.MinoRankedStatus
local MinoRankedStatus = {
	any = -3,
	graveyard = -2,
	wip = -1,
	pending = 0,
	ranked = 1,
	qualified = 3,
	loved = 4,
}

---@param config {request: fun(url: string): {status: integer, body: string}?, string?}
function MinoProvider:new(config)
	self.request = assert(config.request, "request is required")
end

---@param query string
---@param filters {page: integer, status: rizu.dlc.MinoRankedStatus}?
---@return table[]? results
---@return string? error
function MinoProvider:search(query, filters)
	local page = filters and filters.page or 1
	local status = filters and filters.status or "ranked"

	local url = self.search_url .. "?" .. http_util.encode_query_string({
		query = query,
		mode = 3,
		offset = (page - 1) * 100,
		status = MinoRankedStatus[status] or 1,
		amount = 100,
	})

	print("[MinoProvider] Requesting URL:", url)
	local res, err = self.request(url)
	if not res then
		return nil, err or "HTTP request failed"
	end

	local ok, data = pcall(json.decode, res.body)
	if not ok then
		return nil, "Failed to decode JSON response"
	end

	---@cast data rizu.dlc.MinoBeatmapset[]

	local results = {}
	for _, set in ipairs(data) do
		table.insert(results, {
			id = set.id,
			title = set.title,
			artist = set.artist,
			creator = set.creator,
			source = set.source,
			tags = set.tags,
			status = set.status,
			difficulties = set.beatmaps,
			has_video = set.video,
			has_storyboard = set.storyboard,
			thumbnail_url = ("https://assets.ppy.sh/beatmaps/%s/covers/card.jpg"):format(set.id),
		})
	end

	return results
end

---@param id integer
---@return string url
function MinoProvider:getDownloadUrl(id)
	return self.download_url .. id
end

return MinoProvider
