local class = require("class")
local table_util = require("table_util")

---@class rizu.NetworkDiagnosticsSnapshot
---@field dns_requests integer
---@field dns_cache_hits integer
---@field dns_failures integer
---@field http_requests integer
---@field http_failures integer
---@field stream_opens integer
---@field stream_failures integer
---@field downloads integer
---@field download_failures integer
---@field websocket_connects integer
---@field websocket_failures integer
---@field scheduler_errors integer
---@field last_error string?

---@alias rizu.NetworkDiagnosticsCounter
---| "dns_requests"
---| "dns_cache_hits"
---| "dns_failures"
---| "http_requests"
---| "http_failures"
---| "stream_opens"
---| "stream_failures"
---| "downloads"
---| "download_failures"
---| "websocket_connects"
---| "websocket_failures"
---| "scheduler_errors"

---@class rizu.NetworkDiagnostics
---@operator call: rizu.NetworkDiagnostics
---@field counters rizu.NetworkDiagnosticsSnapshot
local NetworkDiagnostics = class()

function NetworkDiagnostics:new()
	self.counters = {
		dns_requests = 0,
		dns_cache_hits = 0,
		dns_failures = 0,
		http_requests = 0,
		http_failures = 0,
		stream_opens = 0,
		stream_failures = 0,
		downloads = 0,
		download_failures = 0,
		websocket_connects = 0,
		websocket_failures = 0,
		scheduler_errors = 0,
	}
end

---@param counter rizu.NetworkDiagnosticsCounter
function NetworkDiagnostics:increment(counter)
	self.counters[counter] = self.counters[counter] + 1
end

---@param counter rizu.NetworkDiagnosticsCounter
---@param err string?
function NetworkDiagnostics:fail(counter, err)
	self:increment(counter)
	if err then
		self.counters.last_error = err
	end
end

---@return rizu.NetworkDiagnosticsSnapshot
function NetworkDiagnostics:snapshot()
	return table_util.copy(self.counters)
end

return NetworkDiagnostics
