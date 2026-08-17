local Message = require("icc.Message")
local SeaClient = require("rizu.online.SeaClient")

local test = {}

local function newClient()
	return SeaClient({setUser = function() end}, {}, {
		createWebsocketConnection = function() return {} end,
		resolveUrl = function() end,
	})
end

---@param t testing.T
function test.return_messages_are_deferred_until_update(t)
	local sea_client = newClient()
	local handled = {}
	function sea_client.task_handler:handleReturn(msg)
		table.insert(handled, msg)
	end
	function sea_client.task_handler:update() end
	sea_client.server_peer.decode = function()
		return Message(1, true, true, "result")
	end

	sea_client.protocol:text("payload", true)
	t:eq(#handled, 0)
	t:eq(#sea_client.pending_returns, 1)

	sea_client:update()
	t:eq(#handled, 1)
	t:eq(handled[1].id, 1)
	t:eq(#sea_client.pending_returns, 0)
end

---@param t testing.T
function test.calls_still_dispatch_immediately(t)
	local sea_client = newClient()
	local handled = 0
	function sea_client.task_handler:handle()
		handled = handled + 1
	end
	sea_client.server_peer.decode = function()
		return Message(1, nil, {"callback"}, false)
	end

	sea_client.protocol:text("payload", true)
	t:eq(handled, 1)
	t:eq(#sea_client.pending_returns, 0)
end

return test
