local ComputeProtocol = require("sea.compute.ComputeProtocol")

local test = {}

local function socket_pair()
	local sent = ""
	local socket = {}
	function socket:send(data)
		sent = sent .. data
		return #data
	end
	function socket:receive(size)
		if sent == "" then
			return nil, "closed", ""
		end
		local data = sent:sub(1, math.min(size, 3))
		sent = sent:sub(#data + 1)
		return data
	end
	return socket
end

---@param t testing.T
function test.round_trip_partial_reads(t)
	local socket = socket_pair()
	t:assert(ComputeProtocol.send(socket, {ok = true, data = "a\0b"}))
	local value = assert(ComputeProtocol.receive(socket))
	t:tdeq(value, {ok = true, data = "a\0b"})
end

---@param t testing.T
function test.rejects_large_payload(t)
	local socket = socket_pair()
	local ok, err = ComputeProtocol.send(socket, {data = string.rep("x", 20)}, 10)
	t:eq(ok, nil)
	t:eq(err, "payload too large")
end

return test
