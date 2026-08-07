local valid = require("valid")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local CosocketServer = require("web.luasocket.CosocketServer")
local ComputeProtocol = require("sea.compute.ComputeProtocol")
local ComputeRequest = require("sea.compute.ComputeRequest")
local ComputeVersion = require("sea.compute.ComputeVersion")
local ReplayComputer = require("sea.compute.ReplayComputer")

local host = os.getenv("RIZU_COMPUTE_HOST") or "127.0.0.1"
local port = tonumber(os.getenv("RIZU_COMPUTE_PORT") or "8191")
local version = ComputeVersion.current()
local timeout = tonumber(os.getenv("RIZU_COMPUTE_TIMEOUT") or "120")
local max_payload_size = tonumber(os.getenv("RIZU_COMPUTE_MAX_PAYLOAD") or tostring(ComputeProtocol.max_payload_size))
assert(port, "invalid RIZU_COMPUTE_PORT")
assert(timeout, "invalid RIZU_COMPUTE_TIMEOUT")
assert(max_payload_size, "invalid RIZU_COMPUTE_MAX_PAYLOAD")

local scheduler = CosocketScheduler()
local computer = ReplayComputer()

---@param client web.CosocketTcpSocket
local function handle(client)
	local request, err = ComputeProtocol.receive(client, max_payload_size)
	if not request then
		ComputeProtocol.send(client, {ok = false, error = err}, max_payload_size)
		return
	end
	if request.version ~= version then
		ComputeProtocol.send(client, {ok = false, error = "compute version mismatch"}, max_payload_size)
		return
	end

	ComputeRequest.restore(request)
	local ok
	ok, err = valid.format(ComputeRequest.validate(request))
	if not ok then
		ComputeProtocol.send(client, {ok = false, error = "invalid compute request: " .. err}, max_payload_size)
		return
	end

	local result
	ok, result, err = xpcall(computer.compute, debug.traceback, computer, request)
	if not ok then
		ComputeProtocol.send(client, {ok = false, error = "internal compute error: " .. tostring(result)}, max_payload_size)
		return
	end
	if not result then
		ComputeProtocol.send(client, {ok = false, error = err}, max_payload_size)
		return
	end
	ComputeProtocol.send(client, {ok = true, result = result}, max_payload_size)
end

local server = CosocketServer(scheduler, handle, {
	backlog = 16,
	client_timeout = timeout,
	max_clients = 1,
})
assert(server:start(host, port))
print(("compute worker listening on %s:%d (%s)"):format(host, port, version))

while true do
	local ok, err = scheduler:update(1)
	if not ok and err then
		error(err)
	end
end
