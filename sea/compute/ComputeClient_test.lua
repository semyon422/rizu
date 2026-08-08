local ComputeClient = require("sea.compute.ComputeClient")
local ComputeFailure = require("sea.compute.ComputeFailure")

local test = {}

local function create_request()
	return {version = "test"}
end

---@param connect_error string?
---@param response table?
local function create_socket(connect_error, response)
	local socket = {}
	function socket:settimeout() end
	function socket:connect()
		if connect_error then
			return nil, connect_error
		end
		return 1
	end
	function socket:send()
		return 1
	end
	function socket:receive(size)
		if not self.response then
			self.response = ("%08x"):format(#require("stbl").encode(response)) .. require("stbl").encode(response)
		end
		local data = self.response:sub(1, size)
		self.response = self.response:sub(#data + 1)
		return data
	end
	function socket:close()
		return 1
	end
	return socket
end

---@param t testing.T
function test.worker_unavailable_is_transient(t)
	local client = ComputeClient({
		host = "127.0.0.1",
		port = 1,
		timeout = 1,
		version = "test",
		socket_factory = function() return create_socket("connection refused") end,
	})
	local request = create_request()
	local original_validate = require("sea.compute.ComputeRequest").validate
	require("sea.compute.ComputeRequest").validate = function() return true end
	local result, failure = client:compute(request)
	require("sea.compute.ComputeRequest").validate = original_validate
	t:eq(result, nil)
	t:eq(failure.kind, "transient")
	t:eq(failure.code, "worker_unavailable")
end

---@param t testing.T
function test.preserves_worker_failure(t)
	local failure = ComputeFailure.permanent("invalid_replay", "bad replay")
	local client = ComputeClient({
		host = "127.0.0.1",
		port = 1,
		timeout = 1,
		version = "test",
		socket_factory = function() return create_socket(nil, {ok = false, failure = failure}) end,
	})
	local original_validate = require("sea.compute.ComputeRequest").validate
	require("sea.compute.ComputeRequest").validate = function() return true end
	local result, returned_failure = client:compute(create_request())
	require("sea.compute.ComputeRequest").validate = original_validate
	t:eq(result, nil)
	t:tdeq(returned_failure, failure)
end

return test
