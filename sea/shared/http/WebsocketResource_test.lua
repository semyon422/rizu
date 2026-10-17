local TestNats = require("icc.nats.TestNats")

local test = {}

---@param t testing.T
---@param failure "connect"|"loop"|nil
local function check_cleanup(t, failure)
	local nc = TestNats()
	local disconnected = 0
	local fake_ws = {
		protocol = {},
		handshake = function() return true end,
		loop = function()
			if failure == "loop" then error("receive failed") end
			return true
		end,
	}
	local fake_connections = {
		task_handler = {},
		getNats = function() return nc end,
		createClientTaskHandler = function() return {} end,
	}
	local fake_domain = {
		user_connections = fake_connections,
		onConnect = function()
			t:eq(#nc.subscribers, 3)
			if failure == "connect" then error("connect failed") end
		end,
		onDisconnect = function()
			t:eq(#nc.subscribers, 0)
			disconnected = disconnected + 1
		end,
	}
	-- Isolate lifecycle failures from the real socket parser and domain/database.
	local path = debug.getinfo(1, "S").source:sub(2):gsub("WebsocketResource_test.lua$", "WebsocketResource.lua")
	local loader = assert(loadfile(path))
	setfenv(loader, setmetatable({require = function(name)
		if name == "web.ws.Websocket" then return function() return fake_ws end end
		if name == "sea.app.Peer" then
			return function()
				local peer = {broadcast_sids = {}, setup_dispatch = function() end}
				function peer:subscribe(subject)
					local _, _, sid = nc:subscribe(subject, function() end)
					self.broadcast_sids[subject] = sid
				end
				return peer
			end
		end
		return require(name)
	end}, {__index = _G}))
	local Resource = loader()
	local resource = Resource(fake_domain, {})
	local ok, err = pcall(resource.server, resource, {}, {}, {
		peer_id = "test:123", ip = "test", port = 123,
	})
	t:eq(ok, failure == nil)
	if failure then t:assert(tostring(err):find(failure == "loop" and "receive failed" or "connect failed", 1, true)) end
	t:eq(disconnected, 1)
	t:eq(#nc.subscribers, 0)
end

---@param t testing.T
function test.normal_disconnect(t)
	check_cleanup(t)
end

---@param t testing.T
function test.failed_on_connect(t)
	check_cleanup(t, "connect")
end

---@param t testing.T
function test.failed_receive_loop(t)
	check_cleanup(t, "loop")
end

return test
