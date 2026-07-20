local class = require("class")
local socket_url = require("socket.url")
local table_util = require("table_util")
local thread = require("thread")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local NetworkDiagnostics = require("rizu.net.NetworkDiagnostics")
local Socks5TcpSocket = require("web.socket.Socks5TcpSocket")
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
---@field proxy rizu.Socks5ProxyConfig?
local NetworkService = class()

---@alias rizu.NetworkStatusState
---| "dns"
---| "connecting"
---| "uploading"
---| "waiting_response"
---| "downloading"
---| "done"
---| "failed"
---| "canceled"

---@class rizu.NetworkStatus
---@field state rizu.NetworkStatusState
---@field url string?
---@field host string?
---@field ip string?
---@field err string?
---@field status integer?
---@field uploaded integer?
---@field downloaded integer?
---@field total integer?
---@field chunk string?
---@field cached boolean?

---@class rizu.NetworkStatusOptions
---@field on_status (fun(status: rizu.NetworkStatus))?

---@class rizu.NetworkStatusHttpOptions: web.HttpStreamOptions
---@field on_status (fun(status: rizu.NetworkStatus))?
---@field status_url string?

---@class rizu.Socks5ProxyConfig: web.Socks5ProxyOptions
---@field enabled boolean

NetworkService.timeout = 10
NetworkService.websocket_read_timeout = 30
NetworkService.tls_verify = true
NetworkService.tls_cafile = "resources/certs/cacert.pem"

local resolve_host_async = thread.async(function(host)
	local socket = require("socket")
	return socket.dns.toip(host)
end)

---@param options {scheduler: web.CosocketScheduler?, timeout: number?, websocket_read_timeout: number?, tls_verify: boolean?, tls_cafile: string?, proxy: rizu.Socks5ProxyConfig?, request_func: function?, stream_factory: function?, resolve_host_func: function?}?
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
	self:setProxy(options.proxy)
end

---@param proxy rizu.Socks5ProxyConfig?
function NetworkService:setProxy(proxy)
	if not proxy or not proxy.enabled then
		self.proxy = nil
		return
	end
	assert(proxy.host ~= "", "SOCKS5 proxy host is required")
	assert(proxy.port >= 1 and proxy.port <= 65535, "SOCKS5 proxy port is invalid")
	self.proxy = proxy
end

---@param stream web.HttpStream
function NetworkService:unregisterStream(stream)
	self.active_streams[stream] = nil
end

---@param stream web.HttpStream
---@param options rizu.NetworkStatusHttpOptions
function NetworkService:registerStream(stream, options)
	self.active_streams[stream] = true

	local on_close = options.on_close
	options.on_close = function(closed_stream)
		self:unregisterStream(closed_stream)
		if closed_stream:isCanceled() then
			self:emitStatus(options, {
				state = "canceled",
				url = options.status_url,
				err = closed_stream:getCancelError(),
			})
		end
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

---@param options rizu.NetworkStatusOptions?
---@param status rizu.NetworkStatus
function NetworkService:emitStatus(options, status)
	local on_status = options and options.on_status
	if on_status then
		on_status(status)
	end
end

---@param options table?
---@param url string
---@return rizu.NetworkStatusHttpOptions
function NetworkService:getStatusOptions(options, url)
	---@type rizu.NetworkStatusHttpOptions
	local status_options = table_util.copy(options)
	local on_status = status_options.on_status
	local on_upload = status_options.on_upload
	local on_download = status_options.on_download

	if on_status or on_upload then
		status_options.on_upload = function(uploaded, total, chunk)
			self:emitStatus(status_options, {
				state = "uploading",
				url = url,
				uploaded = uploaded,
				total = total,
				chunk = chunk,
			})
			if on_upload then
				on_upload(uploaded, total, chunk)
			end
		end
	end

	if on_status or on_download then
		status_options.on_download = function(downloaded, total, chunk)
			self:emitStatus(status_options, {
				state = "downloading",
				url = url,
				downloaded = downloaded,
				total = total,
				chunk = chunk,
			})
			if on_download then
				on_download(downloaded, total, chunk)
			end
		end
	end

	return status_options
end

---@param options rizu.NetworkStatusOptions?
---@param url string
---@param err string?
function NetworkService:emitFailure(options, url, err)
	self:emitStatus(options, {
		state = "failed",
		url = url,
		err = err,
	})
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
---@param options rizu.NetworkStatusOptions?
---@param url string?
---@return string?
---@return string?
function NetworkService:resolveHost(host, options, url)
	local cached = self.dns_cache[host]
	if cached then
		self.diagnostics:increment("dns_cache_hits")
		self:emitStatus(options, {
			state = "dns",
			url = url,
			host = host,
			ip = cached,
			cached = true,
		})
		return cached
	end

	self:emitStatus(options, {
		state = "dns",
		url = url,
		host = host,
		cached = false,
	})

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
---@param options rizu.NetworkStatusOptions?
---@return string?
---@return string?
function NetworkService:resolveUrl(url, options)
	local parsed_url, err = socket_url.parse(url)
	if not parsed_url or not parsed_url.host then
		return nil, err or "invalid url"
	end
	return self:resolveHost(parsed_url.host, options, url)
end

---@param url string
---@param options rizu.NetworkStatusOptions?
---@return string?
---@return string?
---@return string?
function NetworkService:resolveRoute(url, options)
	if not self.proxy then
		local connect_host, err = self:resolveUrl(url, options)
		return connect_host, nil, err
	end

	local parsed_url, err = socket_url.parse(url)
	if not parsed_url or not parsed_url.host then
		return nil, nil, err or "invalid url"
	end
	local proxy_host
	proxy_host, err = self:resolveHost(self.proxy.host, options, url)
	if not proxy_host then
		return nil, nil, err
	end
	return parsed_url.host, proxy_host
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

---@param options web.HttpClientOptions?
---@param proxy_host string?
---@return web.HttpClientOptions
function NetworkService:getRoutedClientOptions(options, proxy_host)
	local client_options = self:getClientOptions(options)
	if not proxy_host or client_options.tcp_socket then
		return client_options
	end

	local ip_version = proxy_host:find(":", 1, true) and 6 or 4
	local tcp_socket = CosocketTcpSocket(assert(client_options.scheduler), ip_version)
	local proxy = assert(self.proxy)
	client_options.tcp_socket = Socks5TcpSocket(tcp_socket, {
		host = proxy_host,
		port = proxy.port,
		username = proxy.username,
		password = proxy.password,
	})
	return client_options
end

---@param url string
---@param body table|string?
---@param options web.HttpRequestOptions?
---@return {status: integer, headers: web.Headers, body: string}?
---@return string?
function NetworkService:request(url, body, options)
	self.diagnostics:increment("http_requests")
	---@type rizu.NetworkStatusHttpOptions
	local request_options = self:getStatusOptions(options, url)
	local connect_host, proxy_host, err = self:resolveRoute(url, request_options)
	if not connect_host then
		self.diagnostics:fail("http_failures", err)
		self:emitFailure(request_options, url, err)
		return nil, err
	end

	request_options = self:getRoutedClientOptions(request_options, proxy_host)
	if request_options.connect_host == nil then
		request_options.connect_host = connect_host
	end
	self:emitStatus(request_options, {
		state = "connecting",
		url = url,
		ip = proxy_host or connect_host,
	})
	local res
	res, err = self.request_func(url, body, request_options)
	if not res then
		self.diagnostics:fail("http_failures", err)
		self:emitFailure(request_options, url, err)
	else
		self:emitStatus(request_options, {
			state = "done",
			url = url,
			status = res.status,
		})
	end
	return res, err
end

---@param url string
---@param options web.HttpStreamOptions?
---@return web.HttpStream?
---@return string?
function NetworkService:openStream(url, options)
	self.diagnostics:increment("stream_opens")
	---@type rizu.NetworkStatusHttpOptions
	local stream_options = self:getStatusOptions(options, url)
	stream_options.status_url = url

	local connect_host, proxy_host, err = self:resolveRoute(url, stream_options)
	if not connect_host then
		self.diagnostics:fail("stream_failures", err)
		self:emitFailure(stream_options, url, err)
		return nil, err
	end

	stream_options = self:getRoutedClientOptions(stream_options, proxy_host)
	if stream_options.connect_host == nil then
		stream_options.connect_host = connect_host
	end

	local stream = self.stream_factory(stream_options)
	self:registerStream(stream, stream_options)
	self:emitStatus(stream_options, {
		state = "connecting",
		url = url,
		ip = proxy_host or connect_host,
	})
	local ok
	ok, err = stream:connect(url)
	if not ok then
		self:unregisterStream(stream)
		self.diagnostics:fail("stream_failures", err)
		self:emitFailure(stream_options, url, err)
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
		self:emitFailure(options, url, err)
		return nil, err
	end

	self:emitStatus(options, {
		state = "waiting_response",
		url = url,
	})

	local body
	body, err = stream:receiveBody()
	if not body then
		stream:close()
		self.diagnostics:fail("download_failures", err)
		if not stream:isCanceled() then
			self:emitFailure(options, url, err)
		end
		return nil, err
	end

	local res = assert(stream.res)
	stream:close()
	self:emitStatus(options, {
		state = "done",
		url = url,
		status = res.status,
	})

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
	---@type rizu.NetworkStatusOptions?
	local status_options = connection.options
	local connect_host, proxy_host, err = self:resolveRoute(url, status_options)
	if not connect_host then
		self.diagnostics:fail("websocket_failures", err)
		self:emitFailure(status_options, url, err)
		return nil, err
	end
	if proxy_host and connection.options then
		connection.options = self:getRoutedClientOptions(connection.options, proxy_host)
	end
	self:emitStatus(status_options, {
		state = "connecting",
		url = url,
		ip = proxy_host or connect_host,
	})
	local ok
	ok, err = connection:connect(url, connect_host)
	if not ok then
		self.diagnostics:fail("websocket_failures", err)
		self:emitFailure(status_options, url, err)
	else
		self:emitStatus(status_options, {
			state = "done",
			url = url,
		})
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
