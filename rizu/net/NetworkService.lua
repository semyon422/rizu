local class = require("class")
local socket_url = require("socket.url")
local table_util = require("table_util")
local thread = require("thread")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local NetworkDiagnostics = require("rizu.net.NetworkDiagnostics")
local WebsocketConnection = require("web.ws.WebsocketConnection")
local HttpStream = require("web.http.HttpStream")
local http_util = require("web.http.util")

---@class rizu.NetworkService
---@operator call: rizu.NetworkService
---@field scheduler web.CosocketScheduler
---@field timeout number
---@field websocket_read_timeout number
---@field tls_verify boolean
---@field tls_cafile string
---@field dns_cache {[string]: string}
---@field active_streams {[web.HttpStream]: true}
---@field request_func fun(url: string, body: table|string?, options: web.HttpRequestOptions?): {status: integer, headers: web.Headers, body: string}?, string?
---@field stream_factory fun(options: web.HttpStreamOptions?): web.HttpStream
---@field resolve_host_func fun(host: string): string?, string?
---@field diagnostics rizu.NetworkDiagnostics
local NetworkService = class()

NetworkService.timeout = 10
NetworkService.websocket_read_timeout = 30
NetworkService.tls_verify = true
NetworkService.tls_cafile = "resources/certs/cacert.pem"

local resolve_host_async = thread.async(function(host)
	local socket = require("socket")
	return socket.dns.toip(host)
end)

---@param options {scheduler: web.CosocketScheduler?, timeout: number?, websocket_read_timeout: number?, tls_verify: boolean?, tls_cafile: string?, request_func: function?, stream_factory: function?, resolve_host_func: function?}?
function NetworkService:new(options)
	options = options or {}
	self.scheduler = options.scheduler or CosocketScheduler()
	if options.timeout ~= nil then
		self.timeout = options.timeout
	end
	if options.websocket_read_timeout ~= nil then
		self.websocket_read_timeout = options.websocket_read_timeout
	end
	if options.tls_verify ~= nil then
		self.tls_verify = options.tls_verify
	end
	if options.tls_cafile ~= nil then
		self.tls_cafile = options.tls_cafile
	end
	self.request_func = options.request_func or http_util.request
	self.stream_factory = options.stream_factory or HttpStream
	self.resolve_host_func = options.resolve_host_func or resolve_host_async
	self.dns_cache = {}
	self.active_streams = {}
	self.diagnostics = NetworkDiagnostics()
end

---@param stream web.HttpStream
function NetworkService:unregisterStream(stream)
	self.active_streams[stream] = nil
end

---@param stream web.HttpStream
---@param options web.HttpStreamOptions
function NetworkService:registerStream(stream, options)
	self.active_streams[stream] = true

	local on_close = options.on_close
	options.on_close = function(closed_stream)
		self:unregisterStream(closed_stream)
		if on_close then
			on_close(closed_stream)
		end
	end
end

---@param err string?
function NetworkService:cancelStreams(err)
	---@type web.HttpStream[]
	local streams = {}
	for stream in pairs(self.active_streams) do
		table.insert(streams, stream)
	end

	for _, stream in ipairs(streams) do
		stream:cancel(err)
	end
end

---@return rizu.NetworkDiagnosticsSnapshot
function NetworkService:getDiagnostics()
	return self.diagnostics:snapshot()
end

---@return web.SslParams
function NetworkService:getSslParams()
	local params = {
		mode = "client",
		protocol = "any",
		options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
		verify = "none",
	}
	if self.tls_verify then
		params.verify = "peer"
		params.cafile = self.tls_cafile
	end
	return params
end

---@param host string
---@return string?
---@return string?
function NetworkService:resolveHost(host)
	local cached = self.dns_cache[host]
	if cached then
		self.diagnostics:increment("dns_cache_hits")
		return cached
	end

	self.diagnostics:increment("dns_requests")
	local ip, err = self.resolve_host_func(host)
	if ip then
		self.dns_cache[host] = ip
	else
		self.diagnostics:fail("dns_failures", err)
	end
	return ip, err
end

---@param url string
---@return string?
---@return string?
function NetworkService:resolveUrl(url)
	local parsed_url, err = socket_url.parse(url)
	if not parsed_url or not parsed_url.host then
		return nil, err or "invalid url"
	end
	return self:resolveHost(parsed_url.host)
end

---@param options web.HttpClientOptions?
---@return web.HttpClientOptions
function NetworkService:getClientOptions(options)
	local client_options = table_util.copy(options)
	if client_options.scheduler == nil then
		client_options.scheduler = self.scheduler
	end
	if client_options.timeout == nil then
		client_options.timeout = self.timeout
	end
	if client_options.ssl_params == nil then
		client_options.ssl_params = self:getSslParams()
	end
	return client_options
end

---@param url string
---@param body table|string?
---@param options web.HttpRequestOptions?
---@return {status: integer, headers: web.Headers, body: string}?
---@return string?
function NetworkService:request(url, body, options)
	self.diagnostics:increment("http_requests")
	local connect_host, err = self:resolveUrl(url)
	if not connect_host then
		self.diagnostics:fail("http_failures", err)
		return nil, err
	end

	---@type web.HttpRequestOptions
	local request_options = self:getClientOptions(options)
	if request_options.connect_host == nil then
		request_options.connect_host = connect_host
	end
	local res
	res, err = self.request_func(url, body, request_options)
	if not res then
		self.diagnostics:fail("http_failures", err)
	end
	return res, err
end

---@param url string
---@param options web.HttpStreamOptions?
---@return web.HttpStream?
---@return string?
function NetworkService:openStream(url, options)
	self.diagnostics:increment("stream_opens")
	local connect_host, err = self:resolveUrl(url)
	if not connect_host then
		self.diagnostics:fail("stream_failures", err)
		return nil, err
	end

	---@type web.HttpStreamOptions
	local stream_options = self:getClientOptions(options)
	if stream_options.connect_host == nil then
		stream_options.connect_host = connect_host
	end

	local stream = self.stream_factory(stream_options)
	self:registerStream(stream, stream_options)
	local ok
	ok, err = stream:connect(url)
	if not ok then
		self:unregisterStream(stream)
		self.diagnostics:fail("stream_failures", err)
		return nil, err
	end
	return stream
end

---@param url string
---@param options web.HttpStreamOptions?
---@return {status: integer, headers: web.Headers, body: string}?
---@return string?
function NetworkService:download(url, options)
	self.diagnostics:increment("downloads")
	local stream, err = self:openStream(url, options)
	if not stream then
		self.diagnostics:fail("download_failures", err)
		return nil, err
	end

	local ok
	ok, err = stream:sendHeaders()
	if not ok then
		stream:close()
		self.diagnostics:fail("download_failures", err)
		return nil, err
	end

	local body
	body, err = stream:receiveBody()
	if not body then
		stream:close()
		self.diagnostics:fail("download_failures", err)
		return nil, err
	end

	local res = assert(stream.res)
	stream:close()

	return {
		status = res.status,
		headers = res.headers,
		body = body,
	}
end

---@param options web.WebsocketClientOptions?
---@return web.WebsocketConnection
function NetworkService:createWebsocketConnection(options)
	local websocket_options = self:getClientOptions(options)
	if websocket_options.read_timeout == nil then
		websocket_options.read_timeout = self.websocket_read_timeout
	end
	return WebsocketConnection(websocket_options)
end

---@param connection web.WebsocketConnection
---@param url string
---@return true?
---@return string?
function NetworkService:connectWebsocket(connection, url)
	self.diagnostics:increment("websocket_connects")
	local connect_host, err = self:resolveUrl(url)
	if not connect_host then
		self.diagnostics:fail("websocket_failures", err)
		return nil, err
	end
	local ok
	ok, err = connection:connect(url, connect_host)
	if not ok then
		self.diagnostics:fail("websocket_failures", err)
	end
	return ok, err
end

---@return boolean?
---@return string?
function NetworkService:update()
	local ok, err = self.scheduler:update(0)
	if not ok and err then
		self.diagnostics:fail("scheduler_errors", err)
	end
	return ok, err
end

return NetworkService
