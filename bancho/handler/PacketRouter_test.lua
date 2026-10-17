local PacketRouter = require("bancho.handler.PacketRouter")
local Binary = require("bancho.protocol.Binary")
local ClientPackets = require("bancho.protocol.ClientPackets")

local test = {}

function test.new(t)
	local router = PacketRouter()
	t:eq(#router.handlers_all, 0)
	t:eq(#router.handlers_restricted, 0)
	t:eq(#router.handled_packets, 0)
end

function test.register(t)
	local router = PacketRouter()
	local handler = {
		parse = function() return {} end,
		handle = function() end,
	}
	router:register(42, handler, "TestPacket", false)
	t:eq(router.handlers_all[42], handler)
	t:eq(router.handlers_restricted[42], nil)
	t:eq(#router.handled_packets, 1)
	t:eq(router.handled_packets[1].name, "TestPacket")
	t:eq(router.handled_packets[1].id, 42)
end

function test.register_restricted(t)
	local router = PacketRouter()
	local handler = {
		parse = function() return {} end,
		handle = function() end,
	}
	router:register(42, handler, "TestPacket", true)
	t:eq(router.handlers_all[42], handler)
	t:eq(router.handlers_restricted[42], handler)
end

function test.getRegistry_unrestricted(t)
	local router = PacketRouter()
	local player = { restricted = false }
	local registry = router:getRegistry(player)
	t:eq(registry, router.handlers_all)
end

function test.getRegistry_restricted(t)
	local router = PacketRouter()
	local player = { restricted = true }
	local registry = router:getRegistry(player)
	t:eq(registry, router.handlers_restricted)
end

function test.dispatch_calls_handler(t)
	local router = PacketRouter()
	local called = false
	local handler = {
		parse = function(_self, reader, bodyLen) return { value = reader:readI32() } end,
		handle = function(_self, server, player, data)
			called = true
			t:eq(data.value, 42)
		end,
	}
	router:register(100, handler)
	router:setServer(nil)

	-- Build packet: ID 100, body = i32(42)
	local body = Binary.writeI32(42)
	local packet = Binary.writeHeader(100, #body) .. body

	local player = { restricted = false }
	router:dispatch(player, packet)
	t:eq(called, true)
end

function test.dispatch_skips_unknown(t)
	local router = PacketRouter()
	router:setServer(nil)

	-- Packet with unknown ID — should be silently skipped
	local body = Binary.writeI32(999)
	local packet = Binary.writeHeader(9999, #body) .. body

	local player = { restricted = false }
	router:dispatch(player, packet) -- should not error
end

function test.dispatch_empty_data(t)
	local router = PacketRouter()
	router:setServer(nil)
	router:dispatch({}, "") -- should not error
end

function test.dispatch_multiple_packets(t)
	local router = PacketRouter()
	local count = 0
	local handler = {
		parse = function(_self, reader, bodyLen) reader:skip(bodyLen) return {} end,
		handle = function() count = count + 1 end,
	}
	router:register(100, handler)
	router:setServer(nil)

	-- Two packets back-to-back
	local body1 = Binary.writeI32(1)
	local body2 = Binary.writeI32(2)
	local packet = Binary.writeHeader(100, #body1) .. body1
		.. Binary.writeHeader(100, #body2) .. body2

	router:dispatch({}, packet)
	t:eq(count, 2)
end

function test.dispatch_restricted_player(t)
	local router = PacketRouter()
	local all_called = false
	local restricted_called = false

	router:register(100, {
		parse = function(_self, reader, bodyLen) reader:skip(bodyLen) return {} end,
		handle = function() all_called = true end,
	})
	router:register(200, {
		parse = function(_self, reader, bodyLen) reader:skip(bodyLen) return {} end,
		handle = function() restricted_called = true end,
	}, nil, true)

	router:setServer(nil)

	-- Restricted player: only packet 200 should be handled
	local body = Binary.writeI32(1)
	local packet100 = Binary.writeHeader(100, #body) .. body
	local packet200 = Binary.writeHeader(200, #body) .. body

	all_called = false
	restricted_called = false
	router:dispatch({ restricted = true }, packet100 .. packet200)
	t:eq(all_called, false)  -- packet 100 not in restricted map
	t:eq(restricted_called, true)  -- packet 200 is in restricted map
end

function test.setServer(t)
	local router = PacketRouter()
	local fake_server = { name = "test" }
	router:setServer(fake_server)
	t:eq(router._server, fake_server)
end

return test
