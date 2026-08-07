local valid = require("valid")
local ComputeProtocol = require("sea.compute.ComputeProtocol")
local ComputeRequest = require("sea.compute.ComputeRequest")
local ComputeResult = require("sea.compute.ComputeResult")
local IReplayComputer = require("sea.compute.IReplayComputer")

---@class sea.ComputeClientOptions
---@field host string
---@field port integer
---@field timeout number
---@field max_payload_size integer?
---@field version string
---@field socket_factory fun(): web.ITcpSocket

---@class sea.ComputeClient: sea.IReplayComputer
---@operator call: sea.ComputeClient
---@field options sea.ComputeClientOptions
local ComputeClient = IReplayComputer + {}

---@param options sea.ComputeClientOptions
function ComputeClient:new(options)
	self.options = options
end

---@param request sea.ComputeRequest
---@return sea.ComputeResult?
---@return string?
function ComputeClient:compute(request)
	if request.version ~= self.options.version then
		return nil, "compute version mismatch"
	end
	local ok, err = valid.format(ComputeRequest.validate(request))
	if not ok then
		return nil, "invalid compute request: " .. err
	end

	local socket = self.options.socket_factory()
	socket:settimeout(self.options.timeout)
	ok, err = socket:connect(self.options.host, self.options.port)
	if not ok then
		socket:close()
		return nil, "connect compute worker: " .. tostring(err)
	end

	ok, err = ComputeProtocol.send(socket, request, self.options.max_payload_size)
	if not ok then
		socket:close()
		return nil, "send compute request: " .. tostring(err)
	end

	local response
	response, err = ComputeProtocol.receive(socket, self.options.max_payload_size)
	socket:close()
	if not response then
		return nil, "receive compute response: " .. tostring(err)
	end
	if not response.ok then
		return nil, tostring(response.error or "compute failed")
	end
	if type(response.result) ~= "table" then
		return nil, "invalid compute response"
	end

	local result = ComputeResult.restore(response.result)
	if result.version ~= self.options.version then
		return nil, "compute version mismatch"
	end
	ok, err = valid.format(ComputeResult.validate(result))
	if not ok then
		return nil, "invalid compute result: " .. err
	end
	return result
end

return ComputeClient
