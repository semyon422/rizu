local class = require("class")
local socket_url = require("socket.url")
local table_util = require("table_util")
local thread = require("thread")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
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
---@field request_func fun(url: string, body: table|string?, options: web.HttpRequestOptions?): {status: integer, headers: web.Headers, body: string}?, string?
---@field stream_factory fun(options: web.HttpStreamOptions?): web.HttpStream
---@field resolve_host_func fun(host: string): string?, string?
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
		return cached
	end

	local ip, err = self.resolve_host_func(host)
	if ip then
		self.dns_cache[host] = ip
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
	local connect_host, err = self:resolveUrl(url)
	if not connect_host then
		return nil, err
	end

	---@type web.HttpRequestOptions
	local request_options = self:getClientOptions(options)
	if request_options.connect_host == nil then
		request_options.connect_host = connect_host
	end
	return self.request_func(url, body, request_options)
end

---@param url string
---@param options web.HttpStreamOptions?
---@return web.HttpStream?
---@return string?
function NetworkService:openStream(url, options)
	local connect_host, err = self:resolveUrl(url)
	if not connect_host then
		return nil, err
	end

	---@type web.HttpStreamOptions
	local stream_options = self:getClientOptions(options)
	if stream_options.connect_host == nil then
		stream_options.connect_host = connect_host
	end

	local stream = self.stream_factory(stream_options)
	local ok
	ok, err = stream:connect(url)
	if not ok then
		return nil, err
	end
	return stream
end

---@param url string
---@param options web.HttpStreamOptions?
---@return {status: integer, headers: web.Headers, body: string}?
---@return string?
function NetworkService:download(url, options)
	local stream, err = self:openStream(url, options)
	if not stream then
		return nil, err
	end

	local ok
	ok, err = stream:sendHeaders()
	if not ok then
		stream:close()
		return nil, err
	end

	local body
	body, err = stream:receiveBody()
	if not body then
		stream:close()
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
	local connect_host, err = self:resolveUrl(url)
	if not connect_host then
		return nil, err
	end
	return connection:connect(url, connect_host)
end

---@return boolean?
---@return string?
function NetworkService:update()
	return self.scheduler:update(0)
end

return NetworkService
