--- HTTP client stub for testing.
---
--- Provides canned responses for osu! API and osu file fetch requests.

local class = require("class")

---@class bancho.stub.HttpClient
local HttpClient = class()

function HttpClient:new()
	---@type table<string, table> url -> response
	self._responses = {}
	return self
end

--- Register a canned response for a URL.
---@param url string
---@param response {status_code: integer, data: table|nil, body: string|nil}
function HttpClient:register(url, response)
	self._responses[url] = response
end

--- Simulate an HTTP GET request.
---@param url string
---@param params? table
---@return {status_code: integer, json: function, read: function}
function HttpClient:get(url, params)
	local response = self._responses[url]
	if not response then
		return {
			status_code = 404,
			json = function() return nil end,
			read = function() return "" end,
			raise_for_status = function() end,
		}
	end

	local body = response.body or ""

	return {
		status_code = response.status_code,
		json = function() return response.data end,
		read = function() return body end,
		raise_for_status = function()
			if response.status_code >= 400 then
				error("HTTP " .. tostring(response.status_code))
			end
		end,
	}
end

return HttpClient
