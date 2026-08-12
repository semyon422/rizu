local class = require("class")
local http_util = require("web.http.util")
local osudirect = require("chart.transform.osudirect")

---@class osudirect.Beatmapset
---@field setId integer
---@field title string
---@field artist string
---@field creator string
---@field submissionStatus string
---@field difficulties string[]?
---@field hasVideo boolean
---@field hasStoryboard boolean

---@class rizu.dlc.providers.OsuDirectProvider : rizu.dlc.IDlcProvider
---@operator call: rizu.dlc.providers.OsuDirectProvider
---@field request fun(url: string): {status: integer, body: string}?, string?
local OsuDirectProvider = class()

local statusMap = {
	all = 4,
	ranked = 0,
	qualified = 3,
	pending = 2,
	graveyard = 5,
}

---@param config {baseUrl: string, downloadUrl: string, request: fun(url: string): {status: integer, body: string}?, string?}
function OsuDirectProvider:new(config)
	self.baseUrl = config.baseUrl
	self.downloadUrl = config.downloadUrl
	self.request = assert(config.request, "request is required")
end

---@param query string
---@param filters table?
---@return table[]? results, string? error
function OsuDirectProvider:search(query, filters)
	filters = filters or {}
	local page = filters.page or 0
	local status = statusMap[filters.status] or filters.status or 4 -- Default to "All"

	local searchPath = osudirect.search(query, status, page)
	local url = self.baseUrl .. searchPath
	
	print("[OsuDirectProvider] Requesting URL:", url)
	local res, err = self.request(url)
	if not res then
		return nil, err or "HTTP request failed"
	end

	local beatmaps, parse_err = osudirect.parse(res.body)
	if not beatmaps then
		return nil, parse_err or "Failed to parse osudirect response"
	end

	---@cast beatmaps osudirect.Beatmapset[]
	---@type table[]
	local results = {}
	for _, b in ipairs(beatmaps) do
		table.insert(results, {
			id = b.setId,
			title = b.title,
			artist = b.artist,
			creator = b.creator,
			status = b.submissionStatus,
			difficulties = b.difficulties,
			has_video = b.hasVideo,
			has_storyboard = b.hasStoryboard,
			thumbnail_url = self:getThumbnailUrl(b.setId),
		})
	end

	return results
end

---@param id string|number
---@return string? url, string? error
function OsuDirectProvider:getDownloadUrl(id)
	return self.downloadUrl:format(id)
end

---@param id string|number
---@return string? url, string? error
function OsuDirectProvider:getThumbnailUrl(id)
	return "https://assets.ppy.sh" .. osudirect.card(tonumber(id) or 0)
end

return OsuDirectProvider
