local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")
local Websocket = require("web.ws.Websocket")
local SphereWebsocket = require("rizu.online.SphereWebsocket")
local socket = require("socket")

local test = {}

---@param t testing.T
---@param sphws rizu.SphereWebsocket
---@param condition fun(): boolean
---@param step fun()?
local function pump_until(t, sphws, condition, step)
	local deadline = socket.gettime() + 2
	while not condition() do
		if step then
			step()
		end
		sphws:update()
		t:assert(socket.gettime() < deadline)
	end
end

---@param t testing.T
function test.cosocket_reader(t)
	local server = assert(socket.tcp4 and socket.tcp4() or socket.tcp())
	assert(server:setoption("reuseaddr", true))
	assert(server:bind("127.0.0.1", 0))
	assert(server:listen(1))
	assert(server:settimeout(0))

	local _ip, port = server:getsockname()
	local scheduler = CosocketScheduler()
	local sphws = SphereWebsocket({scheduler = scheduler})

	---@type TCPSocket?
	local peer
	local server_payload
	local client_payload

	function sphws.protocol:text(payload, fin)
		if fin then
			client_payload = payload
		end
	end

	local function start_server()
		if peer then
			return
		end

		local _peer, err = server:accept()
		if not _peer then
			if err ~= "timeout" then
				error(err)
			end
			return
		end

		peer = _peer
		assert(peer:settimeout(0))

		local server_co = coroutine.create(function()
			local server_tcp = CosocketTcpSocket(scheduler, nil, peer)
			local req = Request(server_tcp)
			local res = Response(server_tcp)
			local ws = Websocket(server_tcp, req, res, "server")

			function ws.protocol:text(payload, fin)
				if fin then
					server_payload = payload
				end
			end

			t:assert(ws:handshake())
			t:assert(ws:step())
			t:assert(ws:send("text", "hello from server"))
		end)
		t:tdeq({coroutine.resume(server_co)}, {true})
	end

	local client_co = coroutine.create(function()
		t:assert(sphws:connect(("ws://127.0.0.1:%d/ws"):format(port)))
		t:assert(sphws.ws:send("text", "hello from client"))
	end)
	t:tdeq({coroutine.resume(client_co)}, {true})

	pump_until(t, sphws, function()
		return server_payload ~= nil and client_payload ~= nil
	end, start_server)

	t:eq(server_payload, "hello from client")
	t:eq(client_payload, "hello from server")

	if peer then
		peer:close()
	end
	server:close()
end

return test
