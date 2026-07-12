local NetworkService = require("rizu.net.NetworkService")

local test = {}

---@param t testing.T
function test.request_resolves_host_and_sets_defaults(t)
	local calls = {}
	local network = NetworkService({
		timeout = 7,
		tls_verify = false,
		resolve_host_func = function(host)
			table.insert(calls, {host = host})
			return "203.0.113.10"
		end,
		request_func = function(url, body, options)
			table.insert(calls, {url = url, body = body, options = options})
			return {
				status = 200,
				headers = {},
				body = "ok",
			}
		end,
	})

	local res, err = network:request("https://example.test/path", {q = "v"})

	t:eq(err, nil)
	t:eq(res.body, "ok")
	t:eq(calls[1].host, "example.test")
	t:eq(calls[2].url, "https://example.test/path")
	t:tdeq(calls[2].body, {q = "v"})
	t:eq(calls[2].options.scheduler, network.scheduler)
	t:eq(calls[2].options.timeout, 7)
	t:eq(calls[2].options.connect_host, "203.0.113.10")
	t:eq(calls[2].options.ssl_params.verify, "none")
end

---@param t testing.T
function test.request_preserves_explicit_options(t)
	local explicit_scheduler = {}
	local explicit_ssl = {verify = "peer"}
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
		request_func = function(_url, _body, options)
			return {
				status = 200,
				headers = {},
				body = options.connect_host,
			}
		end,
	})

	local res = network:request("https://example.test/path", nil, {
		scheduler = explicit_scheduler --[[@as any]],
		timeout = 3,
		ssl_params = explicit_ssl,
		connect_host = "198.51.100.20",
	})

	t:eq(res.body, "198.51.100.20")
end

---@param t testing.T
function test.timeout_zero_is_explicit(t)
	local network = NetworkService({
		timeout = 0,
		request_func = function(_url, _body, options)
			return {
				status = 200,
				headers = {},
				body = tostring(options.timeout),
			}
		end,
		resolve_host_func = function()
			return "203.0.113.10"
		end,
	})

	local res = network:request("https://example.test/path")

	t:eq(res.body, "0")
end

---@param t testing.T
function test.resolve_host_caches_success(t)
	local calls = 0
	local network = NetworkService({
		resolve_host_func = function(host)
			calls = calls + 1
			return host .. ".resolved"
		end,
	})

	t:eq(network:resolveUrl("https://example.test/a"), "example.test.resolved")
	t:eq(network:resolveUrl("https://example.test/b"), "example.test.resolved")
	t:eq(calls, 1)
end

---@param t testing.T
function test.diagnostics_track_dns_cache_and_copy_snapshot(t)
	local network = NetworkService({
		resolve_host_func = function(host)
			return host .. ".resolved"
		end,
	})

	t:eq(network:resolveUrl("https://example.test/a"), "example.test.resolved")
	t:eq(network:resolveUrl("https://example.test/b"), "example.test.resolved")

	local diagnostics = network:getDiagnostics()
	t:eq(diagnostics.dns_requests, 1)
	t:eq(diagnostics.dns_cache_hits, 1)

	diagnostics.dns_requests = 100
	t:eq(network:getDiagnostics().dns_requests, 1)
end

---@param t testing.T
function test.diagnostics_track_request_failures(t)
	local network = NetworkService({
		resolve_host_func = function()
			return nil, "dns failed"
		end,
	})

	local res, err = network:request("https://example.test/path")
	local diagnostics = network:getDiagnostics()

	t:eq(res, nil)
	t:eq(err, "dns failed")
	t:eq(diagnostics.dns_requests, 1)
	t:eq(diagnostics.dns_failures, 1)
	t:eq(diagnostics.http_requests, 1)
	t:eq(diagnostics.http_failures, 1)
	t:eq(diagnostics.last_error, "dns failed")
end

---@class rizu.FakeWebsocketConnectionForNetworkService
---@field connected_url string?
---@field connected_host string?
local FakeWebsocketConnection = {}
FakeWebsocketConnection.__index = FakeWebsocketConnection

---@param url string
---@param connect_host string?
---@return true
function FakeWebsocketConnection:connect(url, connect_host)
	self.connected_url = url
	self.connected_host = connect_host
	return true
end

---@param t testing.T
function test.connect_websocket_resolves_host(t)
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
	})
	local connection = setmetatable({}, FakeWebsocketConnection)

	t:tdeq({network:connectWebsocket(connection --[[@as any]], "wss://example.test/ws")}, {true})
	t:eq(connection.connected_url, "wss://example.test/ws")
	t:eq(connection.connected_host, "203.0.113.10")
end

---@param t testing.T
function test.diagnostics_track_websocket_failures(t)
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
	})
	local connection = {
		connect = function()
			return nil, "connect failed"
		end,
	}

	local ok, err = network:connectWebsocket(connection --[[@as any]], "wss://example.test/ws")
	local diagnostics = network:getDiagnostics()

	t:eq(ok, nil)
	t:eq(err, "connect failed")
	t:eq(diagnostics.websocket_connects, 1)
	t:eq(diagnostics.websocket_failures, 1)
	t:eq(diagnostics.last_error, "connect failed")
end

---@param t testing.T
function test.create_websocket_connection_sets_reader_timeout(t)
	local network = NetworkService()

	local connection = network:createWebsocketConnection()
	local explicit_connection = network:createWebsocketConnection({read_timeout = 5})

	t:eq(connection.options.timeout, 10)
	t:eq(connection.options.read_timeout, 30)
	t:eq(explicit_connection.options.read_timeout, 5)
end

---@class rizu.FakeHttpStreamForNetworkService
---@field options web.HttpStreamOptions
---@field connected_url string?
---@field closed boolean?
---@field canceled boolean?
---@field cancel_err string?
---@field sent_headers boolean?
---@field res table
local FakeHttpStream = {}
FakeHttpStream.__index = FakeHttpStream

---@param options web.HttpStreamOptions
---@return rizu.FakeHttpStreamForNetworkService
local function new_stream(options)
	return setmetatable({
		options = options,
		res = {
			status = 200,
			headers = {},
		},
	}, FakeHttpStream)
end

---@param url string
---@return true
function FakeHttpStream:connect(url)
	self.connected_url = url
	return true
end

---@return true
function FakeHttpStream:sendHeaders()
	self.sent_headers = true
	return true
end

---@return string
function FakeHttpStream:receiveBody()
	return "body"
end

---@return 1
function FakeHttpStream:close()
	if self.closed then
		return 1
	end
	self.closed = true
	local on_close = self.options.on_close
	if on_close then
		on_close(self)
	end
	return 1
end

---@param err string?
---@return 1
function FakeHttpStream:cancel(err)
	self.canceled = true
	self.cancel_err = err or "canceled"
	self:close()
	return 1
end

---@param t testing.T
function test.open_stream_resolves_host_and_sets_defaults(t)
	local created_stream
	local network = NetworkService({
		timeout = 7,
		tls_verify = false,
		resolve_host_func = function()
			return "203.0.113.10"
		end,
		stream_factory = function(options)
			created_stream = new_stream(options)
			return created_stream
		end,
	})

	local stream, err = network:openStream("https://example.test/file.zip", {
		chunk_size = 10,
	})

	t:eq(err, nil)
	t:eq(stream, created_stream)
	t:eq(stream.connected_url, "https://example.test/file.zip")
	t:eq(stream.options.scheduler, network.scheduler)
	t:eq(stream.options.timeout, 7)
	t:eq(stream.options.connect_host, "203.0.113.10")
	t:eq(stream.options.ssl_params.verify, "none")
	t:eq(stream.options.chunk_size, 10)
	t:eq(network.active_streams[stream], true)

	stream:close()
	t:eq(network.active_streams[stream], nil)
end

---@param t testing.T
function test.open_stream_preserves_on_close(t)
	local closed_stream
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
		stream_factory = function(options)
			return new_stream(options)
		end,
	})

	local stream = network:openStream("https://example.test/file.zip", {
		on_close = function(_stream)
			closed_stream = _stream
		end,
	})

	stream:close()

	t:eq(closed_stream, stream)
	t:eq(network.active_streams[stream], nil)
end

---@param t testing.T
function test.cancel_streams_cancels_active_streams(t)
	local created_stream
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
		stream_factory = function(options)
			created_stream = new_stream(options)
			return created_stream
		end,
	})

	local stream = network:openStream("https://example.test/file.zip")

	network:cancelStreams("screen closed")

	t:eq(stream, created_stream)
	t:eq(stream.canceled, true)
	t:eq(stream.cancel_err, "screen closed")
	t:eq(stream.closed, true)
	t:eq(network.active_streams[stream], nil)
end

---@param t testing.T
function test.download_uses_stream_and_closes_it(t)
	local created_stream
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
		stream_factory = function(options)
			created_stream = new_stream(options)
			return created_stream
		end,
	})

	local res, err = network:download("https://example.test/file.zip")

	t:eq(err, nil)
	t:eq(res.status, 200)
	t:eq(res.body, "body")
	t:eq(created_stream.sent_headers, true)
	t:eq(created_stream.closed, true)
end

---@param t testing.T
function test.diagnostics_track_download_failures(t)
	local created_stream
	local network = NetworkService({
		resolve_host_func = function()
			return "203.0.113.10"
		end,
		stream_factory = function(options)
			created_stream = new_stream(options)
			function created_stream:receiveBody()
				return nil, "body failed"
			end
			return created_stream
		end,
	})

	local res, err = network:download("https://example.test/file.zip")
	local diagnostics = network:getDiagnostics()

	t:eq(res, nil)
	t:eq(err, "body failed")
	t:eq(created_stream.closed, true)
	t:eq(diagnostics.stream_opens, 1)
	t:eq(diagnostics.stream_failures, 0)
	t:eq(diagnostics.downloads, 1)
	t:eq(diagnostics.download_failures, 1)
	t:eq(diagnostics.last_error, "body failed")
end

---@param t testing.T
function test.diagnostics_track_scheduler_errors(t)
	local network = NetworkService({
		scheduler = {
			update = function()
				return nil, "select failed"
			end,
		} --[[@as any]],
	})

	local ok, err = network:update()
	local diagnostics = network:getDiagnostics()

	t:eq(ok, nil)
	t:eq(err, "select failed")
	t:eq(diagnostics.scheduler_errors, 1)
	t:eq(diagnostics.last_error, "select failed")
end

---@param t testing.T
function test.ssl_params_verify_by_default(t)
	local network = NetworkService()

	local params = network:getSslParams()

	t:eq(params.verify, "peer")
	t:eq(params.cafile, "resources/certs/cacert.pem")
end

---@param t testing.T
function test.ssl_params_can_disable_verification(t)
	local network = NetworkService({tls_verify = false})

	local params = network:getSslParams()

	t:eq(params.verify, "none")
	t:eq(params.cafile, nil)
end

return test
